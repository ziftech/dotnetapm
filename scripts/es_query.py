#!/usr/bin/env python3
"""Run ES queries using .env; print counts/aggregations only — never secrets."""
import argparse, json, os, ssl, urllib.request
from pathlib import Path

def load_env():
  p = Path('/Users/darklord/dev/dotnetapm/.env')
  env = {}
  for line in p.read_text().splitlines():
    s = line.strip()
    if not s or s.startswith('#') or '=' not in s: continue
    k, v = s.split('=', 1)
    env[k.strip()] = v.strip().strip('"').strip("'")
  return env

def req(method, url, key, body=None):
  data = None if body is None else json.dumps(body).encode()
  r = urllib.request.Request(url, data=data, method=method, headers={
    'Authorization': f'ApiKey {key}',
    'Content-Type': 'application/json',
  })
  ctx = ssl.create_default_context()
  with urllib.request.urlopen(r, context=ctx, timeout=60) as resp:
    return json.loads(resp.read().decode() or '{}')

def main():
  ap = argparse.ArgumentParser()
  ap.add_argument('--label', required=True)
  ap.add_argument('--minutes', type=int, default=15)
  ap.add_argument('--query', default='service_names')
  args = ap.parse_args()
  env = load_env()
  # Serverless: ES_URL may be the APM ingest host; prefer .es. derived from Kibana.
  from urllib.parse import urlparse
  raw_es = env['ES_URL'].rstrip('/')
  kb = env.get('KIBANA_URL', '').rstrip('/')
  es = raw_es
  if '.ingest.' in raw_es and kb and '.kb.' in kb:
    es = 'https://' + urlparse(kb).hostname.replace('.kb.', '.es.')
  key = env['ES_API_KEY']
  # Prefer APM traces/metrics data streams
  index = 'traces-apm*,metrics-apm*,logs-apm*,apm-*'
  if args.query == 'service_names':
    body = {
      "size": 0,
      "query": {"range": {"@timestamp": {"gte": f"now-{args.minutes}m"}}},
      "aggs": {
        "services": {"terms": {"field": "service.name", "size": 20}},
        "tx": {"terms": {"field": "processor.event", "size": 10}},
        "span_types": {"terms": {"field": "span.type", "size": 20}},
      }
    }
  elif args.query == 'errors':
    body = {
      "size": 0,
      "query": {"bool": {"must": [
        {"range": {"@timestamp": {"gte": f"now-{args.minutes}m"}}},
        {"term": {"processor.event": "error"}}
      ]}},
      "aggs": {"by_service": {"terms": {"field": "service.name", "size": 20}}}
    }
  elif args.query == 'spans_sample':
    body = {
      "size": 5,
      "sort": [{"@timestamp": "desc"}],
      "query": {"bool": {"must": [
        {"range": {"@timestamp": {"gte": f"now-{args.minutes}m"}}},
        {"term": {"processor.event": "span"}}
      ]}},
      "_source": ["service.name", "span.name", "span.type", "transaction.name"]
    }
  else:
    raise SystemExit('unknown query')
  try:
    out = req('POST', f'{es}/{index}/_search', key, body)
  except Exception as e:
    print(f'LABEL={args.label} QUERY={args.query} ERROR={type(e).__name__}')
    # Try without wildcard expansion issues
    try:
      out = req('POST', f'{es}/_search', key, {**body, **{}})
      # add index via header? use _all
      out = req('POST', f'{es}/_all/_search', key, body)
    except Exception as e2:
      print(f'FALLBACK_ERROR={type(e2).__name__}')
      return
  hits = out.get('hits', {}).get('total', {})
  total = hits.get('value', hits) if isinstance(hits, dict) else hits
  print(f'LABEL={args.label} QUERY={args.query} TOTAL_HITS={total}')
  aggs = out.get('aggregations') or {}
  for name, agg in aggs.items():
    buckets = agg.get('buckets') or []
    summary = ', '.join(f"{b.get('key')}:{b.get('doc_count')}" for b in buckets[:15])
    print(f'  AGG {name}: {summary or "(empty)"}')
  if args.query == 'spans_sample':
    for h in (out.get('hits') or {}).get('hits') or []:
      s = h.get('_source') or {}
      print(f"  SPAN service={s.get('service',{}).get('name')} name={s.get('span',{}).get('name')} type={s.get('span',{}).get('type')}")

if __name__ == '__main__':
  main()
