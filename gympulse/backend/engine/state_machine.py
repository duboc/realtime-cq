"""Refine watch-reported state using HR thresholds.

States: IDLE, ACTIVE_SET, RESTING, CARDIO
"""


def get_hr_pct(hr, max_hr, resting_hr):
    """Karvonen HR reserve percentage."""
    if max_hr <= resting_hr:
        return 0.0
    return ((hr - resting_hr) / (max_hr - resting_hr)) * 100.0


def refine_state(state, payload):
    """Refine the watch-reported state using HR context.

    The watch uses accelerometer variance to detect states, but we can
    improve accuracy using HR thresholds on the server side.
    """
    watch_state = payload.state
    hr = payload.hr
    hr_pct = get_hr_pct(hr, payload.mhr, payload.rhr)

    state.prev_state = state.current_state
    refined = watch_state

    if watch_state == "ACTIVE_SET":
        # Validate: HR should be rising or elevated during a set
        # If HR is very low, likely a misdetection
        if hr_pct < 30 and hr < 90:
            refined = "IDLE"
        else:
            refined = "ACTIVE_SET"

    elif watch_state == "RESTING":
        # If HR is still very high, might still be in a set
        if hr_pct > 85:
            refined = "ACTIVE_SET"
        else:
            refined = "RESTING"

    elif watch_state == "CARDIO":
        # Sustained elevated HR without set-like acceleration pattern
        if hr_pct > 60:
            refined = "CARDIO"
        else:
            refined = "RESTING"

    elif watch_state == "IDLE":
        # If HR is elevated, might be light activity
        if hr_pct > 50:
            refined = "RESTING"
        else:
            refined = "IDLE"

    state.current_state = refined
    return refined
