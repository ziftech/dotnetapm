#!/usr/bin/env bash
# Deletes lab VM, disk, firewall rules, and optional GCS bucket. Ask before running in interactive use.
set -euo pipefail
PROJECT="${GCP_PROJECT:-elastic-sa}"
ZONE="${GCP_ZONE:-me-central1-a}"
VM="${VM_NAME:-contoso-apm-lab}"
BUCKET="${LAB_BUCKET:-elastic-sa-contoso-apm-lab-yakovkeranchuk}"

echo "About to DELETE lab resources in project=$PROJECT zone=$ZONE"
echo "  instance: $VM (+ boot disk)"
echo "  firewall: contoso-lab-ssh contoso-lab-rdp contoso-lab-http"
echo "  bucket:   gs://$BUCKET (if exists)"
read -r -p "Type DELETE to confirm: " confirm
[[ "$confirm" == "DELETE" ]] || { echo "Aborted"; exit 1; }

gcloud compute instances delete "$VM" --zone="$ZONE" --project="$PROJECT" --quiet || true
# orphaned disk if instance delete left it
gcloud compute disks delete "$VM" --zone="$ZONE" --project="$PROJECT" --quiet 2>/dev/null || true
for rule in contoso-lab-ssh contoso-lab-rdp contoso-lab-http; do
  gcloud compute firewall-rules delete "$rule" --project="$PROJECT" --quiet 2>/dev/null || true
done
gsutil -m rm -r "gs://$BUCKET" 2>/dev/null || true
echo "Teardown finished."
