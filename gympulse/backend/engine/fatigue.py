"""5-factor gym fatigue scoring (0-100).

Adapted from SoccerMonitor FatigueEngine.mc for gym context:
  - Recovery degradation  0-35 (replaces cardiac drift for gym)
  - HR recovery decline   0-25
  - Resting HR elevation  0-20
  - Zone load             0-10
  - Duration              0-10
"""

from engine.state_machine import get_hr_pct


def compute_fatigue(state, payload):
    """Compute gym fatigue score and zone label. Updates state in-place."""
    score = 0.0
    hr = payload.hr
    hr_pct = get_hr_pct(hr, payload.mhr, payload.rhr)

    # Track high intensity time
    if hr_pct > 85:
        state.high_intensity_seconds += 3  # ~3s per data point

    # === Factor 1: Recovery Degradation (0-35) ===
    # As sets accumulate, inter-set recovery gets worse
    if len(state.sets) >= 2:
        recent_sets = state.sets[-3:] if len(state.sets) >= 3 else state.sets
        avg_recovery = sum(s.get("recovery_after", 100) for s in recent_sets) / len(recent_sets)
        # 100% recovery = 0 pts, 0% recovery = 35 pts
        recovery_deg = max(0, (100 - avg_recovery) / 100 * 35)
        score += recovery_deg

    # === Factor 2: HR Recovery Decline (0-25) ===
    # Compare recovery speed of recent sets vs early sets
    if len(state.sets) >= 4:
        early = state.sets[:2]
        recent = state.sets[-2:]
        early_rec = sum(s.get("recovery_after", 100) for s in early) / len(early)
        recent_rec = sum(s.get("recovery_after", 100) for s in recent) / len(recent)
        if early_rec > 0:
            decline = max(0, (early_rec - recent_rec) / early_rec * 100)
            score += min(25, decline * 0.5)

    # === Factor 3: Resting HR Elevation (0-20) ===
    # Rest-period HR creeping up vs baseline
    if state.calibrated and state.baseline_hr > 0 and state.current_state == "RESTING":
        elevation = max(0, (hr - state.baseline_hr) / state.baseline_hr * 100)
        score += min(20, elevation * 2.0)

    # === Factor 4: Zone Load (0-10) ===
    # Current HR zone stress
    if hr_pct > 90:
        score += 10.0
    elif hr_pct > 80:
        score += 7.0
    elif hr_pct > 70:
        score += 4.0
    elif hr_pct > 60:
        score += 2.0

    # === Factor 5: Duration (0-10) ===
    # Longer sessions accumulate more fatigue
    elapsed_min = payload.et / 60000.0
    score += min(10, elapsed_min * 0.15)

    # Clamp
    score = max(0, min(100, score))

    state.fatigue_score = score
    state.fatigue_zone = _get_zone(score)

    return score, state.fatigue_zone


def _get_zone(score):
    if score < 30:
        return "FRESH"
    if score < 55:
        return "MODERATE"
    if score < 75:
        return "TIRED"
    if score < 90:
        return "EXHAUSTED"
    return "CRITICAL"


def get_recommendation(zone):
    """Return workout recommendation based on fatigue zone."""
    return {
        "FRESH": "Full intensity OK",
        "MODERATE": "Monitor recovery between sets",
        "TIRED": "Consider lighter weights or longer rest",
        "EXHAUSTED": "Reduce volume, extend rest periods",
        "CRITICAL": "Stop workout — risk of overtraining",
    }.get(zone, "")
