#!/usr/bin/env bash
# Deletes lab VM, disk, firewall rules, and optional GCS bucket. Ask before running in interactive use.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
[[ -f "$ROOT/.env" ]] && set -a && source "$ROOT/.env" && set +a
PROJECT="${GCP_PROJECT:-elastic-sa}"
ZONE="${GCP_ZONE:-me-central1-a}"
VM="${VM_NAME:-dotnet-apm-lab}"
BUCKET="${LAB_BUCKET:-}"
FW_PREFIX="${LAB_FW_PREFIX:-dotnet-apm-lab}"

echo "About to DELETE lab resources in project=$PROJECT zone=$ZONE"
echo "  instance: $VM (+ boot disk)"
echo "  firewall: ${FW_PREFIX}-ssh ${FW_PREFIX}-rdp ${FW_PREFIX}-http"
echo "  bucket:   ${BUCKET:+gs://$BUCKET}"
read -r -p "Type DELETE to confirm: " confirm
[[ "$confirm" == "DELETE" ]] || { echo "Aborted"; exit 1; }

gcloud compute instances delete "$VM" --zone="$ZONE" --project="$PROJECT" --quiet || true
gcloud compute disks delete "$VM" --zone="$ZONE" --project="$PROJECT" --quiet 2>/dev/null || true
for rule in "${FW_PREFIX}-ssh" "${FW_PREFIX}-rdp" "${FW_PREFIX}-http"; do
  gcloud compute firewall-rules delete "$rule" --project="$PROJECT" --quiet 2>/dev/null || true
done
if [[ -n "$BUCKET" ]]; then
  gsutil -m rm -r "gs://$BUCKET" 2>/dev/null || true
fi
echo "Teardown finished."
