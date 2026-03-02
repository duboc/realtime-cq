"""POST /api/ingest — main data ingestion route.

Parse → calibrate → state refine → fatigue → recovery → detect set boundaries
→ batch Firestore (every 5th) → broadcast WS → return {fat, fz, rec}.
"""

import json
import time

from flask import Blueprint, request, jsonify

from config import db, USE_MEMORY, sessions, ws_connections, FIRESTORE_BATCH_INTERVAL, SESSION_TIMEOUT_SECONDS
from models import IngestPayload, SessionState, SetRecord, RestPeriod
from engine.calibration import update_calibration
from engine.state_machine import refine_state
from engine.fatigue import compute_fatigue, get_recommendation
from engine.recovery import compute_recovery

ingest_bp = Blueprint("ingest", __name__)

_active_session_id = None
_last_data_time = 0.0


def _get_or_create_session():
    global _active_session_id, _last_data_time

    now = time.time()
    if _active_session_id and (now - _last_data_time) < SESSION_TIMEOUT_SECONDS:
        _last_data_time = now
        if _active_session_id not in sessions:
            sessions[_active_session_id] = SessionState(
                session_id=_active_session_id,
                created_at=now,
                last_data_time=now,
            )
        return _active_session_id

    # Create new session
    session_id = f"gym-{int(now)}"

    if not USE_MEMORY and db is not None:
        from google.cloud import firestore as fs
        ref = db.collection("gympulse_sessions").document(session_id)
        ref.set({"created_at": fs.SERVER_TIMESTAMP, "status": "active"})

    sessions[session_id] = SessionState(
        session_id=session_id,
        created_at=now,
        last_data_time=now,
    )
    _active_session_id = session_id
    _last_data_time = now
    return session_id


@ingest_bp.route("/api/ingest", methods=["POST"])
def ingest():
    data = request.get_json(force=True)

    payload = IngestPayload(
        ts=data.get("ts", 0),
        hr=data.get("hr", 0),
        hrv=data.get("hrv", 0),
        ax=data.get("ax", 0),
        ay=data.get("ay", 0),
        az=data.get("az", 0),
        et=data.get("et", 0),
        mhr=data.get("mhr", 190),
        rhr=data.get("rhr", 60),
        state=data.get("state", "IDLE"),
        setNumber=data.get("setNumber", 0),
        repCount=data.get("repCount", 0),
        preRestHR=data.get("preRestHR", 0),
        hrDrop=data.get("hrDrop", 0),
    )

    session_id = _get_or_create_session()
    state = sessions[session_id]
    state.last_data_time = time.time()
    state.data_count += 1

    # --- Calibration ---
    update_calibration(state, payload.hr, payload.hrv)

    # --- State refinement ---
    refined_state = refine_state(state, payload)

    # --- HR tracking ---
    if payload.hr > 0:
        state.hr_history.append(payload.hr)
        if len(state.hr_history) > 300:
            state.hr_history = state.hr_history[-300:]
        state.hr_sum += payload.hr
        state.avg_hr = state.hr_sum / state.data_count
        if payload.hr > state.max_hr_seen:
            state.max_hr_seen = payload.hr

    if payload.hrv > 0:
        state.hrv_history.append(payload.hrv)
        if len(state.hrv_history) > 120:
            state.hrv_history = state.hrv_history[-120:]

    # --- Detect set boundaries ---
    _detect_set_boundaries(state, payload)

    # --- Fatigue ---
    fat_score, fat_zone = compute_fatigue(state, payload)

    # --- Recovery ---
    rec_pct, rec_status = compute_recovery(state, payload)

    # --- Build broadcast data ---
    broadcast = {
        "ts": payload.ts,
        "hr": payload.hr,
        "hrv": payload.hrv,
        "et": payload.et,
        "state": refined_state,
        "fat": round(fat_score, 1),
        "fz": fat_zone,
        "rec": round(rec_pct, 1),
        "rs": rec_status,
        "sn": payload.setNumber,
        "rc": payload.repCount,
        "avgHR": round(state.avg_hr, 1),
        "maxHR": round(state.max_hr_seen, 1),
        "sets": len(state.sets),
        "mhr": payload.mhr,
        "rhr": payload.rhr,
        "recommendation": get_recommendation(fat_zone),
    }
    state.latest = broadcast

    # --- Firestore batch write ---
    if not USE_MEMORY and db is not None and state.data_count % FIRESTORE_BATCH_INTERVAL == 0:
        try:
            from google.cloud import firestore as fs
            doc_data = {**broadcast, "ingested_at": fs.SERVER_TIMESTAMP}
            db.collection("gympulse_sessions").document(session_id).collection("data_points").add(doc_data)
        except Exception:
            pass

    # --- Broadcast via WebSocket ---
    _broadcast_ws(session_id, broadcast)

    return jsonify({"fat": round(fat_score, 1), "fz": fat_zone, "rec": round(rec_pct, 1)})


def _detect_set_boundaries(state, payload):
    """Detect transitions between ACTIVE_SET and RESTING to log sets."""
    prev = state.prev_state
    current = state.current_state

    # Transition into ACTIVE_SET
    if current == "ACTIVE_SET" and prev != "ACTIVE_SET":
        state.current_set_start = payload.et
        state.current_set_hr_values = [payload.hr]
        state.current_set_peak_hr = payload.hr

    # During ACTIVE_SET
    elif current == "ACTIVE_SET":
        state.current_set_hr_values.append(payload.hr)
        if payload.hr > state.current_set_peak_hr:
            state.current_set_peak_hr = payload.hr

    # Transition out of ACTIVE_SET (set ended)
    if prev == "ACTIVE_SET" and current != "ACTIVE_SET":
        if state.current_set_hr_values:
            avg_hr = sum(state.current_set_hr_values) / len(state.current_set_hr_values)
        else:
            avg_hr = payload.hr

        # Determine recovery from previous rest
        recovery_after = 0.0
        if state.rest_periods:
            last_rest = state.rest_periods[-1]
            recovery_after = last_rest.get("recovery_pct", 0)

        set_rec = {
            "set_number": len(state.sets) + 1,
            "start_time": state.current_set_start,
            "end_time": payload.et,
            "peak_hr": state.current_set_peak_hr,
            "avg_hr": round(avg_hr, 1),
            "rep_count": payload.repCount,
            "recovery_after": round(recovery_after, 1),
        }
        state.sets.append(set_rec)

    # Transition into RESTING
    if current == "RESTING" and prev != "RESTING":
        state.rest_start_time = payload.et
        state.rest_start_hr = payload.hr
        state.rest_periods.append({
            "start_time": payload.et,
            "start_hr": payload.hr,
            "lowest_hr": payload.hr,
            "duration_sec": 0,
            "hr_drop": 0,
            "recovery_pct": 0,
        })


def _broadcast_ws(session_id, data):
    """Send data to all WebSocket connections for this session."""
    dead = set()
    msg = json.dumps(data)
    for ws in ws_connections.get(session_id, set()):
        try:
            ws.send(msg)
        except Exception:
            dead.add(ws)
    ws_connections[session_id] -= dead
