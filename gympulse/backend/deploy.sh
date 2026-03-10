#!/bin/bash
# Deploy GymPulse backend to Cloud Run
# Builds React dashboard first, then deploys

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/../dashboard"
STATIC_DIR="$SCRIPT_DIR/static"

# Step 1: Build React dashboard
echo "Building React dashboard..."
cd "$DASHBOARD_DIR"
npm install
npm run build

# Step 2: Copy build output to backend static/
echo "Copying dashboard to backend/static..."
rm -rf "$STATIC_DIR"
cp -r "$DASHBOARD_DIR/dist" "$STATIC_DIR"

# Step 3: Deploy to Cloud Run
echo "Deploying to Cloud Run..."
cd "$SCRIPT_DIR"
gcloud run deploy gympulse \
    --source . \
    --region southamerica-east1 \
    --allow-unauthenticated \
    --session-affinity \
    --max-instances 1 \
    --min-instances 1 \
    --set-env-vars USE_MEMORY=1 \
    --timeout 3600

echo "Deploy complete!"
