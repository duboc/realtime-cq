"""Simulates watch data flowing to the backend for testing the dashboard."""

import json
import math
import random
import time
import urllib.request

URL = "http://127.0.0.1:5555/api/data"

# Start position (San Francisco)
base_lat = 37.7749
base_lon = -122.4194

t = 0
distance = 0.0
calories = 0

print("Sending simulated data to backend... (Ctrl+C to stop)")

while True:
    t += 3
    angle = t * 0.01

    # Simulate a player running in a rough oval
    lat = base_lat + 0.001 * math.sin(angle)
    lon = base_lon + 0.002 * math.cos(angle)

    # Speed varies: jog (2-3 m/s) with occasional sprints (5-7 m/s)
    sprint = random.random() < 0.1
    speed = random.uniform(5.0, 7.0) if sprint else random.uniform(2.0, 3.5)

    distance += speed * 3
    calories += speed * 0.3

    # HR correlates with speed
    base_hr = 130 + speed * 8 + random.uniform(-3, 3)
    hr = min(base_hr, 195)

    # Fatigue ramps up over time
    fatigue = min(95, 5 + t * 0.03 + random.uniform(-2, 2))

    # HRV decreases as fatigue increases
    hrv = max(10, 60 - fatigue * 0.4 + random.uniform(-5, 5))

    payload = {
        "ts": t * 1000,
        "hr": round(hr, 1),
        "spd": round(speed, 2),
        "gspd": round(speed * 0.95, 2),
        "cad": random.randint(155, 185) if speed > 2 else 0,
        "alt": 50 + math.sin(angle * 0.5) * 5,
        "lat": lat,
        "lon": lon,
        "dist": round(distance, 1),
        "cal": round(calories),
        "et": t * 1000,
        "ax": round(random.uniform(-2, 2), 2),
        "ay": round(random.uniform(-1, 1), 2),
        "az": round(9.8 + random.uniform(-1, 1), 2),
        "hrv": round(hrv, 1),
        "hri": random.randint(60, 90),
        "mhr": 190,
        "rhr": 60,
        "fat": round(fatigue, 1),
    }

    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        URL, data=data, headers={"Content-Type": "application/json"}
    )
    try:
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        print(f"  t={t:>5}s  HR={payload['hr']:>5}  spd={payload['spd']:.1f}  fat={payload['fat']:.0f}%  buf={result['buffered']}")
    except Exception as e:
        print(f"  Error: {e}")

    time.sleep(3)
