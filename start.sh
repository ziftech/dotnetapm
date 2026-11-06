#!/usr/bin/env bash
set -euo pipefail
PROJECT="${GCP_PROJECT:-elastic-sa}"
ZONE="${GCP_ZONE:-me-central1-a}"
VM="${VM_NAME:-contoso-apm-lab}"
echo "Starting $VM in $ZONE..."
gcloud compute instances start "$VM" --zone="$ZONE" --project="$PROJECT"
gcloud compute instances describe "$VM" --zone="$ZONE" --project="$PROJECT" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)'
