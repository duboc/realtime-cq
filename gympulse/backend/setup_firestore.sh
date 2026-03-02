#!/bin/bash
# One-time Firestore setup for GymPulse

set -e

PROJECT=$(gcloud config get-value project)
echo "Setting up Firestore for project: $PROJECT"

# Enable Firestore API
gcloud services enable firestore.googleapis.com

# Create Firestore database (if not exists)
gcloud firestore databases create \
    --location=southamerica-east1 \
    --type=firestore-native \
    2>/dev/null || echo "Database already exists"

# Create composite index for session queries
gcloud firestore indexes composite create \
    --collection-group=gympulse_sessions \
    --field-config field-path=status,order=ASCENDING \
    --field-config field-path=created_at,order=DESCENDING \
    2>/dev/null || echo "Index already exists"

echo "Firestore setup complete!"
