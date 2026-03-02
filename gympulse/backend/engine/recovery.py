"""Recovery readiness scoring (0-100%).

Determines if the athlete is ready for the next set:
  - HR drop     40% weight
  - HRV rebound 40% weight
  - Time        20% weight

Returns (pct, status) where status is GO / ALMOST / NOT_READY.
"""


def compute_recovery(state, payload):
    """Compute recovery readiness. Updates state in-place."""
    if state.current_state != "RESTING" or not state.rest_periods:
        # Not in a rest period or no rest data yet
        return state.recovery_pct, state.recovery_status

    hr = payload.hr
    current_rest = state.rest_periods[-1] if state.rest_periods else None

    if current_rest is None:
        return 100.0, "GO"

    start_hr = current_rest.get("start_hr", hr)
    elapsed_sec = (payload.et - current_rest.get("start_time", payload.et)) / 1000.0

    # Track lowest HR during rest
    if hr < current_rest.get("lowest_hr", 999):
        current_rest["lowest_hr"] = hr

    # === Component 1: HR Drop (40%) ===
    # How much has HR dropped from pre-rest peak toward resting HR
    target_drop = start_hr - payload.rhr
    actual_drop = start_hr - hr
    if target_drop > 0:
        hr_drop_pct = min(100, (actual_drop / target_drop) * 100)
    else:
        hr_drop_pct = 100.0
    hr_component = max(0, hr_drop_pct) * 0.40

    # === Component 2: HRV Rebound (40%) ===
    # Has HRV recovered toward baseline?
    hrv_component = 0.0
    if state.calibrated and state.baseline_hrv > 0 and payload.hrv > 0:
        hrv_ratio = min(1.0, payload.hrv / state.baseline_hrv)
        hrv_component = hrv_ratio * 100 * 0.40

    # === Component 3: Time (20%) ===
    # 90s rest = 100% time component, linear scale
    time_pct = min(100, (elapsed_sec / 90.0) * 100)
    time_component = time_pct * 0.20

    recovery = hr_component + hrv_component + time_component
    recovery = max(0, min(100, recovery))

    # Status
    if recovery >= 85:
        status = "GO"
    elif recovery >= 60:
        status = "ALMOST"
    else:
        status = "NOT_READY"

    state.recovery_pct = recovery
    state.recovery_status = status

    # Update rest period tracking
    current_rest["hr_drop"] = actual_drop
    current_rest["duration_sec"] = elapsed_sec
    current_rest["recovery_pct"] = recovery

    return recovery, status
