#!/usr/bin/env bash
# Drive B0 / S1 / narrow / broad: prepare VM weave+profiler, run 10m k6, save summaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
ZONE=me-central1-a
VM=contoso-apm-lab
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
  tail -20 "$OUT/prepare-$stage.log"
}

run_k6() {
  local stage="$1"
  echo "==== K6 $stage 10m @ 10/s ===="
  # Do not pipe through `tail` (it can tear down the pipeline early). Log to file only.
  set +e
  BASE_URL="$BASE_URL" RATE=10 DURATION=10m \
    "$K6" run "$ROOT/k6/overhead-10m.js" \
    --summary-export "$OUT/summary-$stage.json" \
    >"$OUT/k6-$stage.log" 2>&1
  local rc=$?
  set -e
  echo "k6_exit=$rc stage=$stage"
  tail -50 "$OUT/k6-$stage.log" || true
}

# Ensure prepare script on VM
gcloud compute scp "$ROOT/scripts/Prepare-OverheadStage.ps1" "$ROOT/scripts/Run-Overhead10m.ps1" \
  "$ROOT/scripts/Set-WeaveMode.ps1" "$ROOT/scripts/Verify-AssemblyWeave.ps1" \
  "$ROOT/scripts/Configure-ApmPool.ps1" \
  "$VM:/lab/src/scripts/" --zone="$ZONE" --quiet

# Secrets file for Configure-ApmPool (deleted after each use on VM by prepare script)
umask 077
cat > /tmp/apm-stage.env <<EOF
ServerUrl=$ELASTIC_APM_SERVER_URL
ApiKey=$ELASTIC_APM_API_KEY
EOF
gcloud compute scp /tmp/apm-stage.env "$VM:/lab/apm-stage.env" --zone="$ZONE" --quiet
rm -f /tmp/apm-stage.env

for stage in B0 S1 narrow broad; do
  prepare_stage "$stage"
  run_k6 "$stage"
done

python3 <<'PY'
import json,glob,os
out='/Users/darklord/dev/dotnetapm/results/overhead-10m'
rows=[]
for stage in ['B0','S1','narrow','broad']:
  p=f'{out}/summary-{stage}.json'
  if not os.path.exists(p):
    rows.append((stage,'MISSING',None,None,None,None)); continue
  d=json.load(open(p))
  m=d.get('metrics',{})
  def get(path, default=None):
    cur=m
    for k in path.split('.'):
      if not isinstance(cur,dict) or k not in cur: return default
      cur=cur[k]
    return cur
  med=get('http_req_duration.values.med')
  p95=get('http_req_duration.values.p(95)')
  mx=get('http_req_duration.values.max')
  fail=get('http_req_failed.values.rate')
  rate=get('http_reqs.values.rate')
  rows.append((stage, med, p95, mx, fail, rate))

md=['# Overhead 10m @ 10 req/s (k6 constant-arrival-rate)', '',
    '| Stage | med | p95 | max | fail_rate | throughput |',
    '|---|---|---|---|---|---|']
for stage,med,p95,mx,fail,rate in rows:
  def fmt(x,suf=''):
    if x is None: return 'n/a'
    if isinstance(x,float):
      if suf=='ms': return f'{x:.2f}ms'
      if suf=='%': return f'{x*100:.2f}%'
      return f'{x:.3f}'
    return str(x)
  md.append(f'| {stage} | {fmt(med,"ms")} | {fmt(p95,"ms")} | {fmt(mx,"ms")} | {fmt(fail,"%")} | {fmt(rate)}/s |')
md.append('')
md.append('Stages: B0=DisableWeaving+no profiler; S1=DisableWeaving+profiler; narrow=assembly Trace Service$; broad=Service$+Pricing/CallChain/Repository.')
open('/Users/darklord/dev/dotnetapm/results/overhead-table.md','w').write('\n'.join(md)+'\n')
open(f'{out}/overhead-table.md','w').write('\n'.join(md)+'\n')
print('\n'.join(md))
PY

echo "OVERHEAD_SUITE_DONE"
