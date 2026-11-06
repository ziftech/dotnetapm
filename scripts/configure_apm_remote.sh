#!/usr/bin/env bash
# Configure SharedPool APM on the lab VM. Secrets via SCP'd temp file (deleted after).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
MODE="${1:-profiler}"
SERVICE_NAME="${2:-}"
PROJECT="${GCP_PROJECT:-elastic-sa}"
ZONE="${GCP_ZONE:-me-central1-a}"
VM="${VM_NAME:-dotnet-apm-lab}"
USER_NAME="${GCP_SSH_USER:-yakov_keranchuk}"

TMP="$(mktemp)"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT
cat >"$TMP" <<EOF
ELASTIC_APM_SERVER_URL=$ELASTIC_APM_SERVER_URL
ELASTIC_APM_API_KEY=$ELASTIC_APM_API_KEY
EOF

gcloud compute scp "$ROOT/scripts/Configure-ApmPool.ps1" "$TMP" "$USER_NAME@$VM:" --zone="$ZONE" --project="$PROJECT" >/dev/null
# rename secrets file on remote
gcloud compute ssh "$USER_NAME@$VM" --zone="$ZONE" --project="$PROJECT" --command="powershell -NoProfile -Command \"
Move-Item -Force \\\$env:USERPROFILE\\$(basename "$TMP") \\\$env:USERPROFILE\\apm-secrets.env
\$lines = Get-Content \\\$env:USERPROFILE\\apm-secrets.env
\$map = @{}
foreach (\$l in \$lines) { if (\$l -match '^([^=]+)=(.*)$') { \$map[\$Matches[1]] = \$Matches[2] } }
\$args = @{ Mode='$MODE'; ServerUrl=\$map['ELASTIC_APM_SERVER_URL']; ApiKey=\$map['ELASTIC_APM_API_KEY'] }
if ('$SERVICE_NAME' -ne '') { \$args['ServiceName'] = '$SERVICE_NAME' }
& \\\$env:USERPROFILE\\Configure-ApmPool.ps1 @args
Remove-Item -Force \\\$env:USERPROFILE\\apm-secrets.env -ErrorAction SilentlyContinue
\""
