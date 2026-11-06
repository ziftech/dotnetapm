#!/usr/bin/env bash
# Hit checkout, then prove ShipmentsWeb -> TrackingApi share one trace.id across two service.names.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/Users/darklord/Downloads/google-cloud-sdk/bin:${PATH:-}"

ZONE=me-central1-a
VM=contoso-apm-lab
OUT="$ROOT/results/cross-service"
mkdir -p "$OUT"

gcloud compute scp "$ROOT/scripts/Trigger-CrossService.ps1" "$VM:/lab/src/scripts/" --zone="$ZONE" --quiet
echo "== Trigger checkout with per-app ServiceName =="
gcloud compute ssh "$VM" --zone="$ZONE" --command="powershell -NoProfile -ExecutionPolicy Bypass -File C:\\lab\\src\\scripts\\Trigger-CrossService.ps1" \
  | tee "$OUT/trigger.log"

TID=$(grep -oE 'tid=XSVC-[a-f0-9]+' "$OUT/trigger.log" | head -1 | cut -d= -f2)
echo "TID=$TID"
[[ -n "$TID" ]]
sleep 30

ES="$ES_URL"
if [[ "$ES" == *ingest* ]]; then ES="${ES/ingest./es.}"; ES="${ES%/_es}"; fi

curl -sS -H "Authorization: ApiKey ${ES_API_KEY}" -H "Content-Type: application/json" \
  "$ES/traces-apm*/_search" -d "{
  \"size\": 50,
  \"sort\": [{\"@timestamp\": \"desc\"}],
  \"query\": {
    \"bool\": {
      \"must\": [
        {\"range\": {\"@timestamp\": {\"gte\": \"now-15m\"}}},
        {\"query_string\": {\"query\": \"\\\"$TID\\\"\"}}
      ]
    }
  },
  \"_source\": [\"@timestamp\",\"trace.id\",\"transaction.id\",\"parent.id\",\"service.name\",\"transaction.name\",\"span.name\",\"processor.event\",\"url.path\",\"http\"]
}" | tee "$OUT/raw-search.json" | python3 -c '
import json,sys,collections
d=json.load(sys.stdin)
hits=d.get("hits",{}).get("hits",[])
print("hits", len(hits))
by_trace=collections.defaultdict(set)
for h in hits:
  s=h.get("_source",{})
  tid=((s.get("trace") or {}).get("id") if isinstance(s.get("trace"),dict) else None) or s.get("trace.id")
  svc=((s.get("service") or {}).get("name") if isinstance(s.get("service"),dict) else None) or s.get("service.name")
  name=((s.get("transaction") or {}).get("name") if isinstance(s.get("transaction"),dict) else None) or s.get("transaction.name") or ((s.get("span") or {}).get("name") if isinstance(s.get("span"),dict) else None) or s.get("span.name")
  print(s.get("@timestamp"), "trace", tid, "svc", svc, "name", name)
  if tid and svc: by_trace[tid].add(svc)
cross=[(t,svcs) for t,svcs in by_trace.items() if "ShipmentsWeb" in svcs and "TrackingApi" in svcs]
print("CROSS_SERVICE_TRACES", len(cross))
for t,svcs in cross[:5]:
  print("OK", t, sorted(svcs))
open("'"$OUT"'/proof.txt","w").write("\n".join(f"{t} {sorted(svcs)}" for t,svcs in cross) + "\n")
if not cross:
  raise SystemExit("NO_CROSS_SERVICE_TRACE")
'

echo "Prove-CrossServiceTrace done"
