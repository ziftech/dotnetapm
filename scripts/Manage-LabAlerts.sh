#!/usr/bin/env bash
# Fix custom-threshold data views, keep SLO burn rule evaluating, export fired alerts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"

KIBANA_URL="${KIBANA_URL%/}"
AUTH_HDR=(-H "Authorization: ApiKey ${ES_API_KEY}" -H "kbn-xsrf: true" -H "Content-Type: application/json")
OUT="$ROOT/results/alerts"
mkdir -p "$OUT"

echo "== List find rules tagged contoso-lab =="
curl -sS "${AUTH_HDR[@]}" \
  "$KIBANA_URL/api/alerting/rules/_find?per_page=100&filter=alert.attributes.tags:%22contoso-lab%22" \
  | tee "$OUT/rules-before.json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for r in d.get("data",[]):
  print(r["id"], r["name"], r.get("rule_type_id"), r.get("enabled"), (r.get("last_run") or {}).get("outcome"))
print("TOTAL", d.get("total"))
'

# Custom threshold needs an existing data-view id (not a raw multi-index string).
# metrics-* and logs-* are the default Serverless data views.
update_rule() {
  local id="$1" body="$2" file="$3"
  echo "== PUT rule $id =="
  curl -sS "${AUTH_HDR[@]}" -X PUT "$KIBANA_URL/api/alerting/rule/$id" -d "$body" | tee "$file"
  echo
}

HOST_CPU_ID="49ceab45-36d7-43c0-9b72-41affd815bdb"
IIS_ID="245f7c57-0913-43d9-92ed-6926b84a20f6"
SLO_RULE_ID="10c42262-cd2d-493e-a14b-0fb92dec165a"
SLO_ID="${SLO_ID:-95d3b213-1961-42d9-a777-da7d4af806b6}"

# system.cpu.total.norm.pct is 0..1. Use 0.01 (1%) so lab load can trip it.
update_rule "$HOST_CPU_ID" "$(cat <<'JSON'
{
  "name": "lab-host-cpu-high",
  "tags": ["contoso-lab", "infrastructure"],
  "schedule": {"interval": "1m"},
  "params": {
    "criteria": [{
      "comparator": ">",
      "threshold": [0.01],
      "timeSize": 1,
      "timeUnit": "m",
      "metrics": [{"name": "A", "aggType": "avg", "field": "system.cpu.total.norm.pct"}]
    }],
    "alertOnNoData": false,
    "alertOnGroupDisappear": false,
    "searchConfiguration": {
      "query": {"query": "host.name: contoso-apm-lab*", "language": "kuery"},
      "index": "metrics-*"
    }
  },
  "actions": [],
  "notify_when": null,
  "throttle": null
}
JSON
)" "$OUT/updated-host-cpu.json"

update_rule "$IIS_ID" "$(cat <<'JSON'
{
  "name": "lab-iis-apppool-recycle-proxy",
  "tags": ["contoso-lab", "infrastructure"],
  "schedule": {"interval": "1m"},
  "params": {
    "criteria": [{
      "comparator": ">",
      "threshold": [0],
      "timeSize": 5,
      "timeUnit": "m",
      "metrics": [{"name": "A", "aggType": "count"}]
    }],
    "alertOnNoData": false,
    "alertOnGroupDisappear": false,
    "searchConfiguration": {
      "query": {"query": "host.name: contoso-apm-lab* and data_stream.dataset: iis.access", "language": "kuery"},
      "index": "logs-*"
    }
  },
  "actions": [],
  "notify_when": null,
  "throttle": null
}
JSON
)" "$OUT/updated-iis-proxy.json"

# Ensure SLO burn rule stays enabled with a sensitive window so errors trip it.
update_rule "$SLO_RULE_ID" "$(cat <<JSON
{
  "name": "lab-shipmentsweb-slo-burn-rate",
  "tags": ["contoso-lab", "slo"],
  "schedule": {"interval": "1m"},
  "params": {
    "sloId": "$SLO_ID",
    "windows": [
      {"id": "1", "burnRateThreshold": 0.1, "maxBurnRateThreshold": 100, "longWindow": {"value": 5, "unit": "m"}, "shortWindow": {"value": 1, "unit": "m"}, "actionGroup": "slo.burnRate.alert"}
    ]
  },
  "actions": [],
  "notify_when": null,
  "throttle": null
}
JSON
)" "$OUT/updated-slo-burn.json"

# Force immediate run
for id in "$HOST_CPU_ID" "$IIS_ID" "$SLO_RULE_ID"; do
  echo "== Force run $id =="
  curl -sS "${AUTH_HDR[@]}" -X POST "$KIBANA_URL/api/alerting/rule/$id/_run_soon" | tee "$OUT/run-soon-$id.json" || true
  echo
done

sleep 5
echo "== Refresh rule list =="
curl -sS "${AUTH_HDR[@]}" \
  "$KIBANA_URL/api/alerting/rules/_find?per_page=100&filter=alert.attributes.tags:%22contoso-lab%22" \
  | tee "$OUT/rules-after.json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for r in d.get("data",[]):
  lr=r.get("last_run") or {}
  print(r["id"], r["name"], r.get("rule_type_id"), lr.get("outcome"), str(lr.get("outcome_msg",""))[:120])
print("TOTAL", d.get("total"))
'

ES_QUERY_URL="${ES_URL}"
if [[ "$ES_QUERY_URL" == *ingest* ]]; then
  ES_QUERY_URL="${ES_QUERY_URL/ingest./es.}"
  ES_QUERY_URL="${ES_QUERY_URL%/_es}"
fi
curl -sS -H "Authorization: ApiKey ${ES_API_KEY}" -H "Content-Type: application/json" \
  "$ES_QUERY_URL/.alerts-observability.*/_search" -d '{
    "size": 50,
    "sort": [{"@timestamp":"desc"}],
    "query": {"bool": {"should": [
      {"term": {"kibana.alert.rule.tags": "contoso-lab"}},
      {"wildcard": {"kibana.alert.rule.name": "lab-*"}}
    ], "minimum_should_match": 1}}
  }' | tee "$OUT/fired-alerts-es.json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
hits=d.get("hits",{}).get("hits",[])
print("FIRED", len(hits))
for h in hits[:25]:
  s=h.get("_source",{})
  print(s.get("@timestamp"), s.get("kibana.alert.rule.name"), s.get("kibana.alert.status"), str(s.get("kibana.alert.reason",""))[:120])
' || true

echo "Manage-LabAlerts done"
