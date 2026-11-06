#!/usr/bin/env bash
# Re-query: no PricingCalculator spans in the narrow overhead window only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"

OUT="$ROOT/results/weave-proof"
mkdir -p "$OUT"
WIN="$ROOT/results/overhead-10m/window-narrow.txt"
if [[ ! -f "$WIN" ]]; then
  echo "Missing $WIN — run overhead suite first" >&2
  exit 1
fi
START=$(grep START_UTC "$WIN" | cut -d= -f2)
END=$(grep END_UTC "$WIN" | cut -d= -f2)
echo "narrow_window $START .. $END"

ES="$ES_URL"
if [[ "$ES" == *ingest* ]]; then ES="${ES/ingest./es.}"; ES="${ES%/_es}"; fi

curl -sS -H "Authorization: ApiKey ${ES_API_KEY}" -H "Content-Type: application/json" \
  "$ES/traces-apm*/_search" -d "{
  \"size\": 0,
  \"query\": {
    \"bool\": {
      \"must\": [
        {\"range\": {\"@timestamp\": {\"gte\": \"$START\", \"lte\": \"$END\"}}},
        {\"term\": {\"processor.event\": \"span\"}},
        {\"query_string\": {\"query\": \"span.name:*PricingCalculator* OR span.name:*CalculateHeavy*\"}}
      ]
    }
  },
  \"aggs\": {
    \"names\": {\"terms\": {\"field\": \"span.name\", \"size\": 20}}
  }
}" | tee "$OUT/pricing-narrow-window.json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
total=d.get("hits",{}).get("total",{})
val=total.get("value", total) if isinstance(total,dict) else total
print("PricingCalculator_spans_in_narrow_window", val)
buckets=d.get("aggregations",{}).get("names",{}).get("buckets",[])
for b in buckets:
  print(b["key"], b["doc_count"])
if val and val > 0:
  raise SystemExit("UNEXPECTED_PRICING_SPANS_IN_NARROW")
print("NARROW_PRICING_ABSENT_OK")
'

echo "Query-PricingNarrow done"
