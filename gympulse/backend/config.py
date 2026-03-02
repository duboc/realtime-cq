import os
from collections import defaultdict

# --- Mode selection ---
USE_MEMORY = os.environ.get("USE_MEMORY", "").strip() == "1"

# --- Firestore client (lazy init) ---
db = None
if not USE_MEMORY:
    try:
        from google.cloud import firestore
        db = firestore.Client()
    except Exception:
        USE_MEMORY = True

# --- In-memory session cache ---
# { session_id: SessionState }
sessions = {}

# --- WebSocket connection registry ---
# { session_id: set(ws) }
ws_connections = defaultdict(set)

# --- Constants ---
SESSION_TIMEOUT_SECONDS = 300  # 5 min no data = new session
FIRESTORE_BATCH_INTERVAL = 5  # Write every 5th data point
CALIBRATION_POINTS = 100      # ~5 min at 3s intervals
TRANSMIT_INTERVAL_SEC = 3
