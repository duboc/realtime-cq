"""Baseline HR/HRV calibration from first ~100 data points (~5 min at 3s intervals).

Pattern from SoccerMonitor/source/FatigueEngine.mc baseline logic.
"""

from config import CALIBRATION_POINTS


def update_calibration(state, hr, hrv):
    """Accumulate calibration samples. Returns True when calibration completes."""
    if state.calibrated:
        return False

    if hr <= 0:
        return False

    state.cal_hr_sum += hr
    state.cal_hrv_sum += hrv
    state.cal_count += 1

    if state.cal_count >= CALIBRATION_POINTS:
        state.baseline_hr = state.cal_hr_sum / state.cal_count
        state.baseline_hrv = state.cal_hrv_sum / state.cal_count
        state.calibrated = True
        return True

    return False
