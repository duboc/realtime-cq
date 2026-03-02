#!/bin/bash
# Build script for GymPulse Connect IQ app
# Reads GYMPULSE_CLOUD_URL from ../.env and injects it into DataTransmitter.mc

SDK_HOME="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa"
MONKEYC="$SDK_HOME/bin/monkeyc"
DEV_KEY="$HOME/local/projects/realtime-cq/developer_key"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JUNGLE="$PROJECT_DIR/monkey.jungle"
DEVICE="${1:-venu3}"
OUTPUT="$PROJECT_DIR/bin/GymPulse-$DEVICE.prg"
TRANSMITTER="$PROJECT_DIR/source/DataTransmitter.mc"
ENV_FILE="$PROJECT_DIR/../../.env"

mkdir -p "$PROJECT_DIR/bin"

# Load GYMPULSE_CLOUD_URL from .env (fall back to localhost for local dev)
GYMPULSE_CLOUD_URL="http://127.0.0.1:5556/api/ingest"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    if [ -n "$GYMPULSE_CLOUD_URL" ]; then
        echo "Using GYMPULSE_CLOUD_URL from .env: $GYMPULSE_CLOUD_URL"
    else
        echo "No GYMPULSE_CLOUD_URL in .env — using localhost: $GYMPULSE_CLOUD_URL"
    fi
else
    echo "No .env found — using localhost: $GYMPULSE_CLOUD_URL"
fi

# Inject URL into source
sed -i '' "s|CLOUD_URL_PLACEHOLDER|$GYMPULSE_CLOUD_URL|g" "$TRANSMITTER"

# Build
echo "Building GymPulse for $DEVICE..."
"$MONKEYC" \
    -o "$OUTPUT" \
    -f "$JUNGLE" \
    -y "$DEV_KEY" \
    -d "$DEVICE" \
    -w

BUILD_RESULT=$?

# Restore placeholder (keep source clean for git)
sed -i '' "s|$GYMPULSE_CLOUD_URL|CLOUD_URL_PLACEHOLDER|g" "$TRANSMITTER"

if [ $BUILD_RESULT -eq 0 ]; then
    echo "Build successful: $OUTPUT"
    echo ""
    echo "To sideload to watch via USB:"
    echo "  cp \"$OUTPUT\" /Volumes/GARMIN/GARMIN/APPS/GymPulse.prg"
    echo ""
    echo "To run in simulator:"
    echo "  \"$SDK_HOME/bin/connectiq\" &"
    echo "  \"$SDK_HOME/bin/monkeydo\" \"$OUTPUT\" $DEVICE"
else
    echo "Build failed."
    exit 1
fi
