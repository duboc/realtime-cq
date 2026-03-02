#!/bin/bash
# Build script for Soccer Monitor Connect IQ app
# Reads CLOUD_URL from ../.env and injects it into DataTransmitter.mc

SDK_HOME="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa"
MONKEYC="$SDK_HOME/bin/monkeyc"
DEV_KEY="$HOME/local/projects/realtime-cq/developer_key"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JUNGLE="$PROJECT_DIR/monkey.jungle"
DEVICE="${1:-venu3}"
OUTPUT="$PROJECT_DIR/bin/SoccerMonitor-$DEVICE.prg"
TRANSMITTER="$PROJECT_DIR/source/DataTransmitter.mc"
ENV_FILE="$PROJECT_DIR/../.env"

mkdir -p "$PROJECT_DIR/bin"

# Load CLOUD_URL from .env (fall back to localhost for local dev)
CLOUD_URL="http://127.0.0.1:5555/api/data"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo "Using CLOUD_URL from .env: $CLOUD_URL"
else
    echo "No .env found — using localhost: $CLOUD_URL"
fi

# Inject URL into source
sed -i '' "s|CLOUD_URL_PLACEHOLDER|$CLOUD_URL|g" "$TRANSMITTER"

# Build
echo "Building Soccer Monitor for $DEVICE..."
"$MONKEYC" \
    -o "$OUTPUT" \
    -f "$JUNGLE" \
    -y "$DEV_KEY" \
    -d "$DEVICE" \
    -w

BUILD_RESULT=$?

# Restore placeholder (keep source clean for git)
sed -i '' "s|$CLOUD_URL|CLOUD_URL_PLACEHOLDER|g" "$TRANSMITTER"

if [ $BUILD_RESULT -eq 0 ]; then
    echo "Build successful: $OUTPUT"
    echo ""
    echo "To sideload to watch via USB:"
    echo "  cp \"$OUTPUT\" /Volumes/GARMIN/GARMIN/APPS/SoccerMonitor.prg"
    echo ""
    echo "To run in simulator:"
    echo "  \"$SDK_HOME/bin/connectiq\" &"
    echo "  \"$SDK_HOME/bin/monkeydo\" \"$OUTPUT\" $DEVICE"
else
    echo "Build failed."
    exit 1
fi
