#!/usr/bin/env bash
# Drive B0 / S1 / narrow / broad: prepare VM weave+profiler, run 10m k6, require >95% checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/Users/darklord/Downloads/google-cloud-sdk/bin:${PATH:-}"

ZONE=me-central1-a
VM="${VM_NAME:-dotnet-apm-lab}"
BASE_URL="${BASE_URL:-http://34.18.109.143}"
OUT="$ROOT/results/overhead-10m"
mkdir -p "$OUT" "$ROOT/k6"

K6="$(command -v k6)"
export SERVER_URL="$ELASTIC_APM_SERVER_URL"
export API_KEY="$ELASTIC_APM_API_KEY"

prepare_stage() {
  local stage="$1"
  echo "==== PREPARE $stage ===="
  gcloud compute ssh "$VM" --zone="$ZONE" --command="powershell -NoProfile -ExecutionPolicy Bypass -File C:\\lab\\src\\scripts\\Prepare-OverheadStage.ps1 -Stage $stage" \
    > "$OUT/prepare-$stage.log" 2>&1
  tail -40 "$OUT/prepare-$stage.log"
  grep -q "STAGE_READY=$stage" "$OUT/prepare-$stage.log"
}

run_k6() {
  local stage="$1"
  echo "==== K6 $stage 10m @ 10/s ===="
  date -u +"START_UTC=%Y-%m-%dT%H:%M:%SZ" | tee "$OUT/window-$stage.txt"
  set +e
  BASE_URL="$BASE_URL" RATE=10 DURATION=10m \
    "$K6" run "$ROOT/k6/overhead-10m.js" \
    --summary-export "$OUT/summary-$stage.json" \
    >"$OUT/k6-$stage.log" 2>&1
  local rc=$?
  set -e
  date -u +"END_UTC=%Y-%m-%dT%H:%M:%SZ" | tee -a "$OUT/window-$stage.txt"
  echo "k6_exit=$rc stage=$stage"
  tail -60 "$OUT/k6-$stage.log" || true

  python3 - "$OUT/summary-$stage.json" "$stage" <<'PY'
import json,sys
path,stage=sys.argv[1],sys.argv[2]
d=json.load(open(path))
m=d.get("metrics",{})
c=m.get("checks",{}) or {}
# k6 --summary-export uses flat {passes,fails,value}; handle nested values.rate too
rate=c.get("value")
if rate is None:
  rate=(c.get("values") or {}).get("rate")
passes=c.get("passes")
if passes is None:
  passes=(c.get("values") or {}).get("passes")
fails=c.get("fails")
if fails is None:
  fails=(c.get("values") or {}).get("fails")
print(f"checks_rate={rate} passes={passes} fails={fails}")
if rate is None or float(rate) < 0.95:
  raise SystemExit(f"CHECK_GATE_FAIL stage={stage} checks_rate={rate} (need >0.95)")
print(f"CHECK_GATE_OK stage={stage}")
PY
}

echo "==== Sync sources to VM ===="
# One project tree at a time — bulk recursive scp of four trees has been flaky.
for proj in Contoso.Observability Contoso.Shipments.Business TrackingApi ShipmentsWeb; do
  echo "sync $proj"
  gcloud compute scp --recurse "$ROOT/src/$proj" "$VM:/lab/src/src/" --zone="$ZONE" --quiet
done

gcloud compute scp \
  "$ROOT/scripts/Prepare-OverheadStage.ps1" \
  "$ROOT/scripts/Run-Overhead10m.ps1" \
  "$ROOT/scripts/Set-WeaveMode.ps1" \
  "$ROOT/scripts/Verify-AssemblyWeave.ps1" \
  "$ROOT/scripts/Configure-ApmPool.ps1" \
  "$ROOT/scripts/Fix-TrackingBuffers.ps1" \
  "$ROOT/scripts/Fix-DiagnosticSource.ps1" \
  "$VM:/lab/src/scripts/" --zone="$ZONE" --quiet

umask 077
cat > /tmp/apm-stage.env <<EOF
ServerUrl=$ELASTIC_APM_SERVER_URL
ApiKey=$ELASTIC_APM_API_KEY
EOF
gcloud compute scp /tmp/apm-stage.env "$VM:/lab/apm-stage.env" --zone="$ZONE" --quiet
rm -f /tmp/apm-stage.env

STAGES="${OVERHEAD_STAGES:-B0 S1 narrow broad}"
# shellcheck disable=SC2086
for stage in $STAGES; do
  prepare_stage "$stage"
  run_k6 "$stage"
done

python3 <<'PY'
import json,os
out='/Users/darklord/dev/dotnetapm/results/overhead-10m'
rows=[]
for stage in ['B0','S1','narrow','broad']:
  p=f'{out}/summary-{stage}.json'
  if not os.path.exists(p):
    rows.append((stage,'MISSING',None,None,None,None,None)); continue
  d=json.load(open(p))
  m=d.get('metrics',{})
  def get(path, default=None):
    cur=m
    for k in path.split('.'):
      if not isinstance(cur,dict) or k not in cur: return default
      cur=cur[k]
    return cur
  # summary-export is flat under metric key (avg/med/value), not .values.*
  def metric(name, field):
    block=m.get(name) or {}
    if field in block: return block.get(field)
    return get(f'{name}.values.{field}')
  med=metric('http_req_duration','med')
  p95=metric('http_req_duration','p(95)')
  mx=metric('http_req_duration','max')
  fail=metric('http_req_failed','value')
  rate=metric('http_reqs','rate')
  checks=metric('checks','value')
  rows.append((stage, med, p95, mx, fail, rate, checks))

md=['# Overhead 10m @ 10 req/s (k6 constant-arrival-rate)', '',
    '| Stage | med | p95 | max | fail_rate | throughput | checks |',
    '|---|---|---|---|---|---|---|']
for stage,med,p95,mx,fail,rate,checks in rows:
  def fmt(x,suf=''):
    if x is None: return 'n/a'
    if isinstance(x,float):
      if suf=='ms': return f'{x:.2f}ms'
      if suf=='%': return f'{x*100:.2f}%'
      return f'{x:.3f}'
    return str(x)
  md.append(f'| {stage} | {fmt(med,"ms")} | {fmt(p95,"ms")} | {fmt(mx,"ms")} | {fmt(fail,"%")} | {fmt(rate)}/s | {fmt(checks,"%")} |')
md.append('')
md.append('Stages: B0=DisableWeaving+no profiler; S1=DisableWeaving+profiler; narrow=assembly Trace Service$; broad=Service$+Pricing/CallChain/Repository.')
md.append('Gate: checks rate must be >95% for the stage numbers to count.')
open('/Users/darklord/dev/dotnetapm/results/overhead-table.md','w').write('\n'.join(md)+'\n')
open(f'{out}/overhead-table.md','w').write('\n'.join(md)+'\n')
print('\n'.join(md))
PY

echo "OVERHEAD_SUITE_DONE"
