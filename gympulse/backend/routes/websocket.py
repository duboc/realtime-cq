"""WebSocket route for real-time session streaming.

WS /ws/session/<id> — flask-sock based, connection registry, broadcast.
"""

import json

from flask import Blueprint
from flask_sock import Sock

from config import ws_connections, sessions

ws_bp = Blueprint("websocket", __name__)
sock = Sock()


def init_websocket(app):
    """Initialize flask-sock on the app."""
    sock.init_app(app)


@sock.route("/ws/session/<session_id>")
def ws_session(ws, session_id):
    """WebSocket endpoint for a session. Sends real-time updates."""
    ws_connections[session_id].add(ws)

    # Send current state on connect
    state = sessions.get(session_id)
    if state and state.latest:
        try:
            ws.send(json.dumps(state.latest))
        except Exception:
            pass

    try:
        while True:
            # Keep connection alive — client doesn't send data
            msg = ws.receive(timeout=30)
            if msg is None:
                break
    except Exception:
        pass
    finally:
        ws_connections[session_id].discard(ws)
