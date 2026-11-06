#!/usr/bin/env bash
# Deduplicate APM rules, create infrastructure + SLO rules, export fired alerts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"

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
  print(r["id"], r["name"], r.get("rule_type_id"), r.get("enabled"))
print("TOTAL", d.get("total"))
'

echo "== Delete duplicate lab-shipmentsweb-failed-transaction-rate (keep oldest) =="
python3 - <<'PY' "$OUT/rules-before.json" "$OUT/deleted-duplicates.json"
import json,sys,urllib.request,os
path,out=sys.argv[1],sys.argv[2]
d=json.load(open(path))
dup=[r for r in d["data"] if r["name"]=="lab-shipmentsweb-failed-transaction-rate"]
dup=sorted(dup, key=lambda r: r.get("created_at",""))
keep=dup[0]["id"] if dup else None
remove=[r["id"] for r in dup[1:]]
print("keep",keep,"remove",remove)
kb=os.environ["KIBANA_URL"].rstrip("/")
key=os.environ["ES_API_KEY"]
deleted=[]
for rid in remove:
  req=urllib.request.Request(f"{kb}/api/alerting/rule/{rid}", method="DELETE",
    headers={"Authorization":f"ApiKey {key}","kbn-xsrf":"true"})
  try:
    with urllib.request.urlopen(req) as resp:
      deleted.append({"id":rid,"status":resp.status})
  except Exception as e:
    deleted.append({"id":rid,"error":str(e)})
json.dump({"keep":keep,"deleted":deleted}, open(out,"w"), indent=2)
print(open(out).read())
PY

create_rule() {
  local name="$1" body="$2" file="$3"
  echo "== Create/ensure $name =="
  # skip if exists
  if python3 -c "import json; d=json.load(open('$OUT/rules-before.json')); import sys; sys.exit(0 if any(r['name']=='$name' for r in d.get('data',[])) else 1)"; then
    echo "exists: $name"
    return 0
  fi
  curl -sS "${AUTH_HDR[@]}" -X POST "$KIBANA_URL/api/alerting/rule" -d "$body" | tee "$file"
  echo
}

# Infrastructure: host CPU (metrics inventory) — elastic.threshold or metrics.alert.threshold
# Prefer observability.rules.custom_threshold which works on Serverless.
create_rule "lab-host-cpu-high" "$(cat <<'JSON'
{
  "name": "lab-host-cpu-high",
  "tags": ["contoso-lab", "infrastructure"],
  "rule_type_id": "observability.rules.custom_threshold",
  "consumer": "logs",
  "schedule": {"interval": "1m"},
  "params": {
    "criteria": [{
      "comparator": ">",
      "threshold": [50],
      "timeSize": 1,
      "timeUnit": "m",
      "metrics": [{"name": "A", "aggType": "avg", "field": "system.cpu.total.norm.pct"}]
    }],
    "alertOnNoData": false,
    "alertOnGroupDisappear": false,
    "searchConfiguration": {
      "query": {"query": "host.name: contoso-apm-lab*", "language": "kuery"},
      "index": "metrics-*,metricbeat-*"
    }
  },
  "actions": [],
  "enabled": true
}
JSON
)" "$OUT/created-host-cpu.json" || true

create_rule "lab-iis-apppool-recycle-proxy" "$(cat <<'JSON'
{
  "name": "lab-iis-apppool-recycle-proxy",
  "tags": ["contoso-lab", "infrastructure"],
  "rule_type_id": "observability.rules.custom_threshold",
  "consumer": "logs",
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
      "query": {"query": "host.name: contoso-apm-lab* and (event.dataset: iis.access or data_stream.dataset: iis.*)", "language": "kuery"},
      "index": "logs-*,metrics-*"
    }
  },
  "actions": [],
  "enabled": true
}
JSON
)" "$OUT/created-iis-proxy.json" || true

echo "== Ensure SLO exists / burn-rate rule =="
# Create SLO burn rate rule if SLO id known
SLO_ID="${SLO_ID:-95d3b213-1961-42d9-a777-da7d4af806b6}"
create_rule "lab-shipmentsweb-slo-burn-rate" "$(cat <<JSON
{
  "name": "lab-shipmentsweb-slo-burn-rate",
  "tags": ["contoso-lab", "slo"],
  "rule_type_id": "slo.rules.burnRate",
  "consumer": "slo",
  "schedule": {"interval": "1m"},
  "params": {
    "sloId": "$SLO_ID",
    "windows": [
      {"id": "1", "burnRateThreshold": 1.0, "maxBurnRateThreshold": 10, "longWindow": {"value": 1, "unit": "h"}, "shortWindow": {"value": 5, "unit": "m"}, "actionGroup": "slo.burnRate.alert"}
    ]
  },
  "actions": [],
  "enabled": true
}
JSON
)" "$OUT/created-slo-burn.json" || true

echo "== Refresh rule list =="
curl -sS "${AUTH_HDR[@]}" \
  "$KIBANA_URL/api/alerting/rules/_find?per_page=100&filter=alert.attributes.tags:%22contoso-lab%22" \
  | tee "$OUT/rules-after.json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for r in d.get("data",[]):
  print(r["id"], r["name"], r.get("rule_type_id"))
print("TOTAL", d.get("total"))
'

echo "== Export active/fired alerts for lab rules =="
curl -sS "${AUTH_HDR[@]}" \
  "$KIBANA_URL/api/alerts/alerts/_find?per_page=100" \
  > "$OUT/alerts-all.json" || true
# Also query ES .alerts* / .internal.alerts*
ES_QUERY_URL="${ES_URL}"
# Prefer derived ES from Kibana host if ingest URL
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
for h in hits[:20]:
  s=h.get("_source",{})
  print(s.get("@timestamp"), s.get("kibana.alert.rule.name"), s.get("kibana.alert.status"), s.get("kibana.alert.reason","")[:120])
' || true

echo "Manage-LabAlerts done"
