#!/bin/bash
# Run GymPulse backend locally with in-memory mode
export USE_MEMORY=1
export FLASK_APP=app.py
cd "$(dirname "$0")"
python -m flask run --host 0.0.0.0 --port 5556
