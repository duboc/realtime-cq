# RealTime CQ — Soccer Performance Monitor

Real-time soccer performance monitoring system: a Garmin watch app collects biometric and motion data, streams it to a cloud backend, and displays it on a live web dashboard.

## Architecture

```
Garmin Watch              Cloud Run (FastAPI)         Firestore          Browser
  POST /api/data ────────► Ingest + Store ──────────► Native Mode        Dashboard
  every 3 seconds                                     sessions/          (polling)
                                                      data_points/
```

## Components

### Watch App (`SoccerMonitor/`)
Garmin Connect IQ app (Monkey C) that collects:
- Heart rate, HRV (RMSSD), RR intervals
- GPS position, speed, altitude
- Cadence, accelerometer (25 Hz)
- On-watch fatigue score (composite 0-100)

Transmits JSON payload via HTTP POST every 3 seconds.

**Supported devices:** Venu 3, Venu 3S, Fenix 7 series, FR 965/955/265, Epix Pro

### Backend (`backend/`)
FastAPI service deployed on Cloud Run:
- `POST /api/data` — ingest from watch, write to Firestore
- `GET /api/history` — cursor-based polling for dashboard
- `GET /` — serves the web dashboard
- Session management with 5-minute auto-timeout

### Dashboard (`backend/static/`)
Dark-themed real-time web dashboard:
- Heart rate and HRV line charts (Chart.js)
- Fatigue gauge (color-coded 0-100%)
- GPS track (Leaflet + OpenStreetMap)
- Speed, distance, calories, cadence, elapsed time

## Setup

### Prerequisites
- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (8.4.1+)
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- Python 3.12+

### 1. Clone and configure

```bash
git clone <repo-url> && cd realtime-cq
cp .env.example .env
# Edit .env with your Cloud Run URL after deploying
```

### 2. Set up Firestore

```bash
cd backend
./setup_firestore.sh
```

### 3. Deploy backend

```bash
cd backend
./deploy.sh
# Copy the Cloud Run URL into .env as CLOUD_URL
```

### 4. Build and sideload watch app

```bash
cd SoccerMonitor
./build.sh venu3
# Connect watch via USB, then:
cp bin/SoccerMonitor-venu3.prg /Volumes/GARMIN/GARMIN/APPS/SoccerMonitor.prg
```

### 5. Open dashboard

Navigate to your Cloud Run URL in a browser.

## Local Development

```bash
# Backend (in-memory mode, no Firestore needed)
cd backend
USE_MEMORY=1 uvicorn server:app --port 5555 --reload

# Simulate watch data
python3 test_feed.py

# Dashboard
open http://localhost:5555
```

## Project Structure

```
realtime-cq/
├── .env.example              # Template for CLOUD_URL
├── backend/
│   ├── server.py             # FastAPI backend
│   ├── requirements.txt      # Python dependencies
│   ├── Dockerfile            # Cloud Run container
│   ├── deploy.sh             # gcloud run deploy
│   ├── setup_firestore.sh    # One-time Firestore setup
│   ├── test_feed.py          # Simulated watch data
│   └── static/
│       ├── index.html        # Dashboard layout
│       ├── dashboard.js      # Polling, charts, map
│       └── dashboard.css     # Dark theme
├── SoccerMonitor/
│   ├── build.sh              # Build script (reads .env)
│   ├── run.sh                # Simulator launcher
│   ├── manifest.xml          # Permissions, devices
│   └── source/
│       ├── SoccerMonitorApp.mc
│       ├── SensorCollector.mc
│       ├── DataTransmitter.mc
│       ├── HRVCalculator.mc
│       ├── FatigueEngine.mc
│       └── SoccerMonitorView.mc
└── local_server.py           # Simple local test server
```
