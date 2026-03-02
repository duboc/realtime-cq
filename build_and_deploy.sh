#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-venu3}"

echo "========================================="
echo "  RealTime CQ — Build & Deploy"
echo "========================================="
echo ""

# --- Step 1: Build Watch App ---
echo "[1/2] Building Garmin watch app for $DEVICE..."
echo "-----------------------------------------"
cd "$ROOT_DIR/SoccerMonitor"
bash build.sh "$DEVICE"
echo ""

# --- Step 2: Deploy Backend ---
echo "[2/2] Deploying backend to Cloud Run..."
echo "-----------------------------------------"
cd "$ROOT_DIR/backend"
bash deploy.sh
echo ""

echo "========================================="
echo "  All done!"
echo "========================================="
echo ""
echo "  Watch app:  SoccerMonitor/bin/SoccerMonitor-$DEVICE.prg"
echo "  Backend:    Deployed to Cloud Run (us-central1)"
echo ""
