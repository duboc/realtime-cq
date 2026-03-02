#!/usr/bin/env bash
set -e

PROJECT=$(gcloud config get-value project)
REGION="us-central1"

echo "Project: $PROJECT"
echo "Region:  $REGION"
echo ""

# 1. Enable Firestore API
echo "Enabling Firestore API..."
gcloud services enable firestore.googleapis.com --project="$PROJECT"

# 2. Create Firestore database in Native mode
echo "Creating Firestore database (Native mode)..."
gcloud firestore databases create \
  --project="$PROJECT" \
  --location="$REGION" \
  --type=firestore-native \
  2>/dev/null || echo "Database already exists (this is fine)"

# 3. Create composite index for session lookup
echo "Creating composite index on sessions (status + created_at)..."
gcloud firestore indexes composite create \
  --project="$PROJECT" \
  --collection-group=sessions \
  --field-config field-path=status,order=ASCENDING \
  --field-config field-path=created_at,order=DESCENDING \
  2>/dev/null || echo "Index may already exist (this is fine)"

echo ""
echo "Firestore setup complete."
