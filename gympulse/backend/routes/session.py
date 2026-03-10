"""Session management routes.

GET /api/session/<id>/live   — latest state
GET /api/session/<id>/sets   — set log
GET /api/session/<id>/history — data point history
GET /api/session/<id>/summary — session summary
GET /api/sessions            — list sessions
"""

from flask import Blueprint, jsonify

from config import sessions

session_bp = Blueprint("session", __name__)


@session_bp.route("/api/session/<session_id>/live")
def session_live(session_id):
    state = sessions.get(session_id)
    if not state:
        return jsonify({"error": "Session not found"}), 404
    return jsonify(state.latest)


@session_bp.route("/api/session/<session_id>/sets")
def session_sets(session_id):
    state = sessions.get(session_id)
    if not state:
        return jsonify({"error": "Session not found"}), 404
    return jsonify({
        "sets": state.sets,
        "total": len(state.sets),
        "rest_periods": state.rest_periods,
    })


@session_bp.route("/api/session/<session_id>/history")
def session_history(session_id):
    state = sessions.get(session_id)
    if not state:
        return jsonify({"error": "Session not found"}), 404
    return jsonify({
        "hr_history": state.hr_history[-100:],
        "hrv_history": state.hrv_history[-100:],
        "data_count": state.data_count,
    })


@session_bp.route("/api/session/<session_id>/summary")
def session_summary(session_id):
    state = sessions.get(session_id)
    if not state:
        return jsonify({"error": "Session not found"}), 404

    elapsed_min = 0
    if state.sets:
        last_set = state.sets[-1]
        elapsed_min = last_set.get("end_time", 0) / 60000

    return jsonify({
        "session_id": session_id,
        "total_sets": len(state.sets),
        "avg_hr": round(state.avg_hr, 1),
        "max_hr": round(state.max_hr_seen, 1),
        "fatigue_score": round(state.fatigue_score, 1),
        "fatigue_zone": state.fatigue_zone,
        "elapsed_min": round(elapsed_min, 1),
        "calibrated": state.calibrated,
        "baseline_hr": round(state.baseline_hr, 1),
        "baseline_hrv": round(state.baseline_hrv, 1),
    })


@session_bp.route("/api/sessions")
def list_sessions():
    result = []
    for sid, state in sessions.items():
        result.append({
            "session_id": sid,
            "status": state.status,
            "sets": len(state.sets),
            "fatigue": round(state.fatigue_score, 1),
            "data_count": state.data_count,
        })
    return jsonify({"sessions": result})
