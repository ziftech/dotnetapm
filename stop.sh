#!/usr/bin/env bash
set -euo pipefail
PROJECT="${GCP_PROJECT:-elastic-sa}"
ZONE="${GCP_ZONE:-me-central1-a}"
VM="${VM_NAME:-contoso-apm-lab}"
echo "Stopping $VM in $ZONE (disk still bills)..."
gcloud compute instances stop "$VM" --zone="$ZONE" --project="$PROJECT"
echo "Stopped. Reminder: pd-balanced disk and any static IP still incur charges."
