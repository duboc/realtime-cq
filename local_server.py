#!/usr/bin/env python3
"""Local server to receive SoccerMonitor data and display it in real time."""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

class SoccerDataHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error":"invalid json"}')
            return

        ts = datetime.now().strftime("%H:%M:%S")
        print(f"\n{'='*60}")
        print(f"[{ts}] POST {self.path}")
        print(f"{'='*60}")
        print(f"  HR:       {data.get('hr', '-')} bpm")
        print(f"  Speed:    {data.get('spd', '-')} m/s")
        print(f"  GPS Spd:  {data.get('gspd', '-')} m/s")
        print(f"  Cadence:  {data.get('cad', '-')} spm")
        print(f"  Altitude: {data.get('alt', '-')} m")
        print(f"  Lat/Lon:  {data.get('lat', '-')}, {data.get('lon', '-')}")
        print(f"  Distance: {data.get('dist', '-')} m")
        print(f"  Calories: {data.get('cal', '-')} kcal")
        print(f"  Elapsed:  {data.get('et', '-')} ms")
        print(f"  Accel:    x={data.get('ax', '-')} y={data.get('ay', '-')} z={data.get('az', '-')}")
        print(f"  HRV:      {data.get('hrv', '-')} (RMSSD)")
        print(f"  HR Index: {data.get('hri', '-')}")
        print(f"  Max HR:   {data.get('mhr', '-')} bpm")
        print(f"  Rest HR:  {data.get('rhr', '-')} bpm")
        print(f"  Fatigue:  {data.get('fat', '-')}%")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok"}).encode())

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "running"}).encode())

    def log_message(self, format, *args):
        # Suppress default request logging to keep output clean
        pass

if __name__ == "__main__":
    port = 8080
    server = HTTPServer(("0.0.0.0", port), SoccerDataHandler)
    print(f"Soccer Monitor local server listening on http://localhost:{port}")
    print("Waiting for data from simulator...\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
