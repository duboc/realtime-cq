#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
gcloud run deploy realtime-cq \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --session-affinity
