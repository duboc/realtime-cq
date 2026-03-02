"""RMSSD tracking and trend analysis.

Pattern from SoccerMonitor/source/HRVCalculator.mc.
"""

import math

MAX_WINDOW = 120


def compute_rmssd(rr_intervals):
    """Compute RMSSD from a list of RR intervals (ms)."""
    if len(rr_intervals) < 4:
        return 0.0

    sum_sq_diff = 0.0
    count = 0

    for i in range(1, len(rr_intervals)):
        diff = rr_intervals[i] - rr_intervals[i - 1]
        prev = rr_intervals[i - 1]
        if prev > 0 and abs(diff) / prev < 0.20:
            sum_sq_diff += diff * diff
            count += 1

    if count == 0:
        return 0.0

    return math.sqrt(sum_sq_diff / count)


def analyze_hrv_trend(state):
    """Analyze HRV trend: returns (current_rmssd, trend_direction, decline_pct).

    trend_direction: 'stable', 'declining', 'improving'
    decline_pct: % decline from baseline (0 if improving)
    """
    history = state.hrv_history
    if len(history) < 5:
        return (history[-1] if history else 0.0), "stable", 0.0

    current = sum(history[-5:]) / 5
    recent_10 = sum(history[-10:]) / min(len(history), 10) if len(history) >= 10 else current

    if not state.calibrated or state.baseline_hrv <= 0:
        return current, "stable", 0.0

    decline_pct = max(0, (state.baseline_hrv - current) / state.baseline_hrv * 100)

    if current < recent_10 * 0.95:
        trend = "declining"
    elif current > recent_10 * 1.05:
        trend = "improving"
    else:
        trend = "stable"

    return current, trend, decline_pct
