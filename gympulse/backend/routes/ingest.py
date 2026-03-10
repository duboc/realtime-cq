"""POST /api/ingest — main data ingestion route.

Parse → calibrate → state refine → fatigue → recovery → detect set boundaries
→ workout phase → form analysis → batch Firestore (every 5th) → broadcast
→ return {fat, fz, rec, recoveryETA}.
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
from engine.workout_phase import detect_workout_phase
from engine.form_analysis import compute_form_consistency

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
        setDuration=data.get("setDuration", 0),
        restDuration=data.get("restDuration", 0),
        avgRepDuration=data.get("avgRepDuration", 0),
        accelVariance=data.get("accelVariance", 0),
        peakHR=data.get("peakHR", 0),
        weight=data.get("weight", 0),
        confirmedReps=data.get("confirmedReps", 0),
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

    # --- Track accel variance for form analysis ---
    if refined_state == "ACTIVE_SET" and payload.accelVariance > 0:
        state.current_set_variances.append(payload.accelVariance)

    # --- Detect set boundaries ---
    _detect_set_boundaries(state, payload)

    # --- Fatigue ---
    fat_score, fat_zone = compute_fatigue(state, payload)

    # --- Recovery ---
    rec_pct, rec_status = compute_recovery(state, payload)

    # --- Workout phase ---
    workout_phase = detect_workout_phase(state, fat_score)
    state.workout_phase = workout_phase

    # --- Form consistency ---
    form_consistency = compute_form_consistency(state.current_set_variances)

    # --- Computed intelligence ---
    recovery_eta = _compute_recovery_eta(state, payload, rec_pct)
    hr_recovery_rate = _compute_hr_recovery_rate(state, payload)
    set_comparison = _compute_set_comparison(state)
    total_reps = _compute_total_reps(state, payload)
    avg_set_duration = _compute_avg_set_duration(state)
    avg_rest_duration = _compute_avg_rest_duration(state)

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
        # New intelligence fields
        "restTimer": round(payload.restDuration / 1000, 1) if payload.restDuration > 0 else 0,
        "recoveryETA": round(recovery_eta, 0),
        "setDuration": round(payload.setDuration / 1000, 1) if payload.setDuration > 0 else 0,
        "avgSetDuration": round(avg_set_duration, 1),
        "avgRestDuration": round(avg_rest_duration, 1),
        "hrRecoveryRate": round(hr_recovery_rate, 2),
        "workoutPhase": workout_phase,
        "formConsistency": round(form_consistency, 1),
        "setComparison": set_comparison,
        "totalReps": total_reps,
        "weight": payload.weight,
        "confirmedReps": payload.confirmedReps,
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

    return jsonify({
        "fat": round(fat_score, 1),
        "fz": fat_zone,
        "rec": round(rec_pct, 1),
        "recoveryETA": round(recovery_eta, 0),
    })


def _detect_set_boundaries(state, payload):
    """Detect transitions between ACTIVE_SET and RESTING to log sets."""
    prev = state.prev_state
    current = state.current_state

    # Transition into ACTIVE_SET
    if current == "ACTIVE_SET" and prev != "ACTIVE_SET":
        state.current_set_start = payload.et
        state.current_set_hr_values = [payload.hr]
        state.current_set_peak_hr = payload.hr
        state.current_set_variances = []  # Reset for new set

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

        # Compute set duration
        duration_ms = payload.setDuration if payload.setDuration > 0 else (payload.et - state.current_set_start)
        duration_sec = duration_ms / 1000.0

        # Use confirmedReps over auto repCount when available
        rep_count = payload.confirmedReps if payload.confirmedReps > 0 else payload.repCount

        set_rec = {
            "set_number": len(state.sets) + 1,
            "start_time": state.current_set_start,
            "end_time": payload.et,
            "peak_hr": state.current_set_peak_hr,
            "avg_hr": round(avg_hr, 1),
            "rep_count": rep_count,
            "recovery_after": round(recovery_after, 1),
            "duration_sec": round(duration_sec, 1),
            "avg_rep_duration": round(payload.avgRepDuration / 1000.0, 2) if payload.avgRepDuration > 0 else 0,
            "weight": payload.weight,
        }
        state.sets.append(set_rec)

        # Store average variance for this set
        if state.current_set_variances:
            avg_var = sum(state.current_set_variances) / len(state.current_set_variances)
            state.set_accel_variances.append(avg_var)
        state.current_set_variances = []

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

    # Update ongoing rest period
    if current == "RESTING" and state.rest_periods:
        rp = state.rest_periods[-1]
        rp["duration_sec"] = round(payload.restDuration / 1000.0, 1) if payload.restDuration > 0 else round((payload.et - state.rest_start_time) / 1000.0, 1)
        if payload.hr > 0 and payload.hr < rp.get("lowest_hr", 999):
            rp["lowest_hr"] = payload.hr
        rp["hr_drop"] = round(rp["start_hr"] - payload.hr, 1)


def _compute_recovery_eta(state, payload, current_rec_pct):
    """Estimate seconds until recovery reaches 85% (GO threshold)."""
    if current_rec_pct >= 85:
        return 0

    # Use HR recovery rate to project time to GO
    hr_rate = _compute_hr_recovery_rate(state, payload)
    if hr_rate <= 0:
        # Default estimate based on typical recovery
        remaining_pct = 85 - current_rec_pct
        return remaining_pct * 1.5  # ~1.5s per percent as rough estimate

    # Estimate remaining HR drop needed
    target_rec = 85.0
    remaining_pct = target_rec - current_rec_pct
    # Each BPM drop contributes ~2-3% recovery, so estimate seconds
    bpm_needed = remaining_pct / 2.5
    eta = bpm_needed / hr_rate if hr_rate > 0 else 60
    return max(0, min(300, eta))  # Cap at 5 minutes


def _compute_hr_recovery_rate(state, payload):
    """Compute HR recovery rate in BPM/second during rest."""
    if state.current_state != "RESTING" or not state.rest_periods:
        return 0.0

    rp = state.rest_periods[-1]
    duration = rp.get("duration_sec", 0)
    hr_drop = rp.get("hr_drop", 0)

    if duration > 3 and hr_drop > 0:
        return hr_drop / duration

    return 0.0


def _compute_set_comparison(state):
    """Compare current/last set to averages (reps, duration, peak HR)."""
    if len(state.sets) < 2:
        return None

    last_set = state.sets[-1]
    prev_sets = state.sets[:-1]

    avg_reps = sum(s.get("rep_count", 0) for s in prev_sets) / len(prev_sets)
    avg_peak = sum(s.get("peak_hr", 0) for s in prev_sets) / len(prev_sets)
    avg_dur = sum(s.get("duration_sec", 0) for s in prev_sets) / len(prev_sets)

    return {
        "repsDelta": last_set.get("rep_count", 0) - round(avg_reps),
        "peakHRDelta": round(last_set.get("peak_hr", 0) - avg_peak, 1),
        "durationDelta": round(last_set.get("duration_sec", 0) - avg_dur, 1),
    }


def _compute_total_reps(state, payload):
    """Total reps across all completed sets plus current set."""
    total = sum(s.get("rep_count", 0) for s in state.sets)
    if state.current_state == "ACTIVE_SET":
        total += payload.repCount
    return total


def _compute_avg_set_duration(state):
    """Average set duration in seconds across completed sets."""
    if not state.sets:
        return 0
    durations = [s.get("duration_sec", 0) for s in state.sets if s.get("duration_sec", 0) > 0]
    if not durations:
        return 0
    return sum(durations) / len(durations)


def _compute_avg_rest_duration(state):
    """Average rest duration in seconds across rest periods."""
    if not state.rest_periods:
        return 0
    durations = [r.get("duration_sec", 0) for r in state.rest_periods if r.get("duration_sec", 0) > 0]
    if not durations:
        return 0
    return sum(durations) / len(durations)


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
