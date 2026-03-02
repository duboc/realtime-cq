"""Flask application factory for GymPulse backend."""

import os

from flask import Flask, send_from_directory
from flask_cors import CORS

from routes.ingest import ingest_bp
from routes.session import session_bp
from routes.websocket import ws_bp, init_websocket


def create_app():
    static_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
    app = Flask(__name__, static_folder=static_dir, static_url_path="")
    CORS(app)

    # Register blueprints
    app.register_blueprint(ingest_bp)
    app.register_blueprint(session_bp)
    app.register_blueprint(ws_bp)

    # Initialize WebSocket
    init_websocket(app)

    # Serve dashboard — SPA with assets at root
    @app.route("/")
    def index():
        return send_from_directory(static_dir, "index.html")

    return app


app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5556))
    app.run(host="0.0.0.0", port=port, debug=True)
