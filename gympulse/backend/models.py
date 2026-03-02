from dataclasses import dataclass, field
from typing import Optional


@dataclass
class IngestPayload:
    ts: float = 0.0
    hr: float = 0.0
    hrv: float = 0.0
    ax: float = 0.0
    ay: float = 0.0
    az: float = 0.0
    et: float = 0.0          # elapsed time ms
    mhr: float = 190.0       # max HR
    rhr: float = 60.0        # resting HR
    state: str = "IDLE"      # watch-reported: IDLE/ACTIVE_SET/RESTING/CARDIO
    setNumber: int = 0
    repCount: int = 0
    preRestHR: float = 0.0   # HR at end of last set
    hrDrop: float = 0.0      # HR recovery since last set


@dataclass
class SetRecord:
    set_number: int = 0
    start_time: float = 0.0   # ms
    end_time: float = 0.0     # ms
    peak_hr: float = 0.0
    avg_hr: float = 0.0
    rep_count: int = 0
    recovery_after: float = 0.0  # % recovered before next set


@dataclass
class RestPeriod:
    start_time: float = 0.0
    start_hr: float = 0.0
    lowest_hr: float = 0.0
    duration_sec: float = 0.0
    hr_drop: float = 0.0
    recovery_pct: float = 0.0


@dataclass
class SessionState:
    session_id: str = ""
    created_at: float = 0.0
    last_data_time: float = 0.0
    data_count: int = 0
    status: str = "active"

    # Calibration
    calibrated: bool = False
    baseline_hr: float = 0.0
    baseline_hrv: float = 0.0
    cal_hr_sum: float = 0.0
    cal_hrv_sum: float = 0.0
    cal_count: int = 0

    # HR tracking
    hr_history: list = field(default_factory=list)
    hrv_history: list = field(default_factory=list)
    max_hr_seen: float = 0.0
    avg_hr: float = 0.0
    hr_sum: float = 0.0

    # State
    current_state: str = "IDLE"
    prev_state: str = "IDLE"

    # Sets
    sets: list = field(default_factory=list)        # list of SetRecord dicts
    current_set_start: float = 0.0
    current_set_hr_values: list = field(default_factory=list)
    current_set_peak_hr: float = 0.0

    # Rest
    rest_periods: list = field(default_factory=list)  # list of RestPeriod dicts
    rest_start_time: float = 0.0
    rest_start_hr: float = 0.0

    # Fatigue
    fatigue_score: float = 0.0
    fatigue_zone: str = "FRESH"
    high_intensity_seconds: float = 0.0

    # Recovery
    recovery_pct: float = 100.0
    recovery_status: str = "GO"

    # Latest broadcast data
    latest: dict = field(default_factory=dict)
