#!/bin/bash
# Build, launch simulator, and run Soccer Monitor app
# Usage: ./run.sh [device]
# Example: ./run.sh venu3

SDK_HOME="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa"
MONKEYC="$SDK_HOME/bin/monkeyc"
MONKEYDO="$SDK_HOME/bin/monkeydo"
CONNECTIQ="$SDK_HOME/bin/connectiq"
DEV_KEY="$HOME/local/projects/realtime-cq/developer_key"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JUNGLE="$PROJECT_DIR/monkey.jungle"
DEVICE="${1:-venu3}"
OUTPUT="$PROJECT_DIR/bin/SoccerMonitor-$DEVICE.prg"

mkdir -p "$PROJECT_DIR/bin"

# Step 1: Build
echo "=== Building Soccer Monitor for $DEVICE ==="
"$MONKEYC" \
    -o "$OUTPUT" \
    -f "$JUNGLE" \
    -y "$DEV_KEY" \
    -d "$DEVICE" \
    -w

if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi
echo "Build successful."
echo ""

# Step 2: Kill any existing simulator
pkill -f "ConnectIQ" 2>/dev/null
sleep 1

# Step 3: Launch simulator
echo "=== Starting simulator ==="
"$CONNECTIQ" &
SIMPID=$!
echo "Simulator PID: $SIMPID"

# Step 4: Wait for simulator to be ready
echo "Waiting for simulator to start..."
sleep 4

# Step 5: Load app into simulator
echo "=== Loading app into simulator ==="
"$MONKEYDO" "$OUTPUT" "$DEVICE"
