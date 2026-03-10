"""Form consistency analysis from accelerometer variance."""

import math


def compute_form_consistency(set_variances):
    """Score form consistency 0-100% from coefficient of variation of accel variances.

    Low CV = consistent movement patterns = good form.
    High CV = erratic movements = degraded form.

    Args:
        set_variances: list of accel variance values within the current set

    Returns:
        float: form consistency score 0-100 (100 = perfect consistency)
    """
    if not set_variances or len(set_variances) < 3:
        return 100.0  # Not enough data, assume good form

    mean = sum(set_variances) / len(set_variances)
    if mean <= 0:
        return 100.0

    sum_sq_dev = sum((v - mean) ** 2 for v in set_variances)
    std_dev = math.sqrt(sum_sq_dev / len(set_variances))

    cv = std_dev / mean  # coefficient of variation

    # Map CV to a 0-100 score
    # CV ~0.0 = 100% consistency, CV >= 1.0 = 0% consistency
    score = max(0.0, min(100.0, (1.0 - cv) * 100.0))
    return round(score, 1)
