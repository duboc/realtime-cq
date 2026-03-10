"""Workout phase detection: WARMUP / WORKING / FATIGUED."""


def detect_workout_phase(state, fatigue_score):
    """Determine current workout phase based on set count, elapsed time, and fatigue.

    - WARMUP: fewer than 2 completed sets AND less than 5 minutes elapsed
    - FATIGUED: fatigue score > 65
    - WORKING: everything else
    """
    elapsed_min = 0
    if state.sets:
        last_set = state.sets[-1]
        elapsed_min = last_set.get("end_time", 0) / 60000
    elif state.last_data_time and state.created_at:
        elapsed_min = (state.last_data_time - state.created_at) / 60

    completed_sets = len(state.sets)

    if completed_sets < 2 and elapsed_min < 5:
        return "WARMUP"
    elif fatigue_score > 65:
        return "FATIGUED"
    else:
        return "WORKING"
