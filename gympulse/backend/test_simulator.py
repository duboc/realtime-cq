"""Simulate a full gym workout for testing.

Phases: warmup → 15 sets (3 exercises x 5 sets) → cardio → cooldown
POSTs to /api/ingest every 3 seconds.
"""

import json
import math
import random
import time
import urllib.request

URL = "http://127.0.0.1:5556/api/ingest"

t = 0
set_number = 0
rep_count = 0
state = "IDLE"
pre_rest_hr = 0
hr_drop = 0
session_max_hr = 0
phase = "warmup"
set_start_t = 0
rest_start_t = 0
current_exercise_sets = 0
exercise_count = 0
set_duration = 0
rest_duration = 0
avg_rep_duration = 0.0
accel_variance = 0.0
peak_hr = 0.0

print("GymPulse Simulator — full gym workout")
print("=" * 50)

while True:
    t += 3
    et = t * 1000  # elapsed time in ms
    elapsed_min = t / 60

    # --- Phase logic ---
    if phase == "warmup" and elapsed_min > 5:
        phase = "sets"
        print("\n--- STARTING SETS ---")

    if phase == "sets" and set_number >= 15:
        phase = "cardio"
        state = "CARDIO"
        print("\n--- CARDIO PHASE ---")

    if phase == "cardio" and elapsed_min > (5 + 15 * 1.5 + 10):
        phase = "cooldown"
        state = "IDLE"
        print("\n--- COOLDOWN ---")

    if phase == "cooldown" and elapsed_min > (5 + 15 * 1.5 + 10 + 5):
        print("\n--- WORKOUT COMPLETE ---")
        break

    # --- Simulate HR based on phase ---
    if phase == "warmup":
        state = "IDLE"
        base_hr = 70 + elapsed_min * 4 + random.uniform(-2, 2)
        rep_count = 0
        set_number = 0
        accel_variance = random.uniform(1000, 5000)
        set_duration = 0
        rest_duration = 0

    elif phase == "sets":
        # Each set: ~30s active + ~60s rest
        cycle_t = t - set_start_t if state == "ACTIVE_SET" else t - rest_start_t

        if state == "IDLE" or state == "RESTING":
            if state == "IDLE":
                # Start first set
                state = "ACTIVE_SET"
                set_number += 1
                current_exercise_sets += 1
                set_start_t = t
                rep_count = 0
                peak_hr = 0
                set_duration = 0
                rest_duration = 0
                avg_rep_duration = 0.0
                print(f"  Set {set_number} START (exercise {exercise_count + 1})")

            elif cycle_t > 60 + random.randint(-10, 15):
                # Rest complete, start new set
                state = "ACTIVE_SET"
                set_number += 1
                current_exercise_sets += 1
                set_start_t = t
                rep_count = 0
                peak_hr = 0
                set_duration = 0
                rest_duration = 0
                avg_rep_duration = 0.0

                if current_exercise_sets > 5:
                    exercise_count += 1
                    current_exercise_sets = 1
                    print(f"\n  Switching to exercise {exercise_count + 1}")

                print(f"  Set {set_number} START")

            # During rest: HR drops
            rest_sec = cycle_t
            rest_duration = rest_sec * 1000  # ms
            set_duration = 0  # Not in a set
            accel_variance = random.uniform(500, 3000)  # Low during rest
            hr_decay = min(40, rest_sec * 0.5)
            base_hr = pre_rest_hr - hr_decay + random.uniform(-2, 2)
            hr_drop = pre_rest_hr - base_hr

        if state == "ACTIVE_SET":
            set_sec = t - set_start_t
            set_duration = set_sec * 1000  # ms

            # HR ramps up during set
            fatigue_boost = set_number * 1.5  # accumulating fatigue
            base_hr = 130 + set_sec * 1.5 + fatigue_boost + random.uniform(-3, 3)
            base_hr = min(base_hr, 185 + fatigue_boost * 0.3)

            # Track peak HR in set
            if base_hr > peak_hr:
                peak_hr = base_hr

            # Rep counting (one rep every ~3-4s)
            rep_count = min(12, set_sec // 3)
            if rep_count > 0:
                avg_rep_duration = set_duration / rep_count

            # Accel variance during set (high, with some variation for form)
            accel_variance = 80000 + random.uniform(-20000, 20000)
            # Degrade form consistency as fatigue builds
            if set_number > 10:
                accel_variance += random.uniform(0, 30000)

            # End set after 25-40s
            if set_sec > random.randint(25, 40):
                pre_rest_hr = base_hr
                state = "RESTING"
                rest_start_t = t
                rest_duration = 0
                hr_drop = 0
                print(f"  Set {set_number} END — {rep_count} reps, peak HR {base_hr:.0f}")

    elif phase == "cardio":
        # Steady-state cardio
        base_hr = 140 + math.sin(t * 0.05) * 8 + random.uniform(-3, 3)
        rep_count = 0
        accel_variance = random.uniform(8000, 15000)
        set_duration = 0
        rest_duration = 0

    elif phase == "cooldown":
        cooldown_t = elapsed_min - (5 + 15 * 1.5 + 10)
        base_hr = 120 - cooldown_t * 10 + random.uniform(-2, 2)
        base_hr = max(65, base_hr)
        accel_variance = random.uniform(500, 2000)
        set_duration = 0
        rest_duration = 0

    hr = max(55, min(200, base_hr))
    if hr > session_max_hr:
        session_max_hr = hr

    # HRV: inversely correlated with HR intensity
    hrv_base = max(8, 65 - (hr - 60) * 0.4 + random.uniform(-5, 5))

    # Accel: high variance during sets, low during rest
    if state == "ACTIVE_SET":
        ax = random.uniform(-800, 800)
        ay = random.uniform(-600, 600)
        az = 980 + random.uniform(-400, 400)
    else:
        ax = random.uniform(-50, 50)
        ay = random.uniform(-30, 30)
        az = 980 + random.uniform(-20, 20)

    payload = {
        "ts": et,
        "hr": round(hr, 1),
        "hrv": round(hrv_base, 1),
        "ax": round(ax, 1),
        "ay": round(ay, 1),
        "az": round(az, 1),
        "et": et,
        "mhr": 190,
        "rhr": 60,
        "state": state,
        "setNumber": set_number,
        "repCount": int(rep_count),
        "preRestHR": round(pre_rest_hr, 1),
        "hrDrop": round(hr_drop, 1),
        "setDuration": round(set_duration, 1),
        "restDuration": round(rest_duration, 1),
        "avgRepDuration": round(avg_rep_duration, 1),
        "accelVariance": round(accel_variance, 1),
        "peakHR": round(peak_hr, 1),
    }

    data = json.dumps(payload).encode()
    req = urllib.request.Request(URL, data=data, headers={"Content-Type": "application/json"})

    try:
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        fat = result.get("fat", 0)
        fz = result.get("fz", "?")
        rec = result.get("rec", 0)
        eta = result.get("recoveryETA", 0)
        eta_str = f"ETA:{eta:>3.0f}s" if eta > 0 else "     "
        print(f"  t={t:>5}s  HR={hr:>5.0f}  state={state:<11}  fat={fat:>4.0f}% ({fz:<10})  rec={rec:>4.0f}%  {eta_str}  sets={set_number}")
    except Exception as e:
        print(f"  Error: {e}")

    time.sleep(3)
