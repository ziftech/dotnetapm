#!/usr/bin/env python3
"""Capture Kibana APM waterfall for LegacyShipmentService.* spans (real UI, not HTML rebuild)."""
from __future__ import annotations

import json
import os
import ssl
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_env() -> dict:
    env: dict[str, str] = {}
    for line in (ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
        os.environ.setdefault(k.strip(), env[k.strip()])
    return env


def es_base(env: dict) -> str:
    raw = env["ES_URL"].rstrip("/")
    kb = env.get("KIBANA_URL", "").rstrip("/")
    if ".ingest." in raw and kb and ".kb." in kb:
        return "https://" + urllib.parse.urlparse(kb).hostname.replace(".kb.", ".es.")
    return raw


def find_live_vb_trace(env: dict) -> tuple[str, str, str, str]:
    es = es_base(env)
    key = env["ES_API_KEY"]
    ctx = ssl.create_default_context()

    def search(body: dict) -> dict:
        req = urllib.request.Request(
            f"{es}/traces-apm*/_search",
            data=json.dumps(body).encode(),
            method="POST",
            headers={"Authorization": f"ApiKey {key}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
            return json.loads(resp.read().decode())

    out = search(
        {
            "size": 10,
            "sort": [{"@timestamp": "desc"}],
            "query": {
                "bool": {
                    "must": [
                        {"range": {"@timestamp": {"gte": "now-2h"}}},
                        {"term": {"service.name": "ShipmentsWeb"}},
                        {"term": {"processor.event": "transaction"}},
                        {"term": {"transaction.name": "POST Checkout/Index"}},
                    ]
                }
            },
            "_source": ["trace.id", "transaction.id", "@timestamp"],
        }
    )
    for hit in out.get("hits", {}).get("hits", []):
        src = hit["_source"]
        tid = src["trace"]["id"]
        spans = search(
            {
                "size": 1,
                "query": {
                    "bool": {
                        "must": [
                            {"term": {"trace.id": tid}},
                            {"term": {"span.name": "LegacyShipmentService.EnrichQuoteNote"}},
                        ]
                    }
                },
                "_source": ["span.id"],
            }
        )
        if spans.get("hits", {}).get("total", {}).get("value", 0) > 0:
            span_id = spans["hits"]["hits"][0]["_source"]["span"]["id"]
            return tid, src["transaction"]["id"], span_id, src["@timestamp"]
    raise SystemExit("No recent ShipmentsWeb checkout with LegacyShipmentService spans")


def main() -> int:
    env = load_env()
    kibana = env["KIBANA_URL"].rstrip("/")
    kibana_host = urllib.parse.urlparse(kibana).hostname or ""
    api_key = env["ES_API_KEY"]
    out = ROOT / "screenshots"
    out.mkdir(parents=True, exist_ok=True)
    path = out / "16-vb-legacyshipmentservice-waterfall.png"

    trace_id, tx_id, span_id, ts = find_live_vb_trace(env)
    print("live_trace", trace_id, "tx", tx_id, "span", span_id, "ts", ts)

    range_q = "rangeFrom=now-2h&rangeTo=now&environment=lab"
    inventory = f"{kibana}/app/apm/services?{range_q}"
    waterfall = (
        f"{kibana}/app/apm/services/ShipmentsWeb/transactions/view"
        f"?{range_q}&transactionId={tx_id}&traceId={trace_id}"
        f"&spanId={span_id}&waterfallItemId={span_id}"
        f"&transactionName=POST%20Checkout%2FIndex&transactionType=request"
        f"&comparisonEnabled=false"
    )
    print("waterfall_url", waterfall)

    from playwright.sync_api import sync_playwright

    ok = False
    body = ""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Do NOT set Authorization via extra_http_headers — it leaks onto CDN
        # (kibana.estccdn.com) and LaunchDarkly fetches and breaks CORS/bootstrap.
        # Only attach ApiKey on same-origin Kibana requests.
        context = browser.new_context(viewport={"width": 1680, "height": 1200})

        def attach_auth(route):
            headers = {
                **route.request.headers,
                "authorization": f"ApiKey {api_key}",
                "kbn-xsrf": "true",
            }
            route.continue_(headers=headers)

        context.route(f"https://{kibana_host}/**", attach_auth)
        page = context.new_page()
        console_errs: list[str] = []
        page.on(
            "console",
            lambda msg: console_errs.append(f"{msg.type}: {msg.text}") if msg.type == "error" else None,
        )
        page.on("pageerror", lambda exc: console_errs.append(f"pageerror: {exc}"))

        print("warm", inventory)
        page.goto(inventory, wait_until="domcontentloaded", timeout=120000)
        time.sleep(12)
        warm_body = page.inner_text("body")
        print(
            "warm_body_has_refresh",
            "Refresh the page" in warm_body,
            "bootstrap_fail",
            "Elastic did not load properly" in warm_body,
            "len",
            len(warm_body),
        )

        for attempt in range(4):
            print("waterfall_attempt", attempt)
            page.goto(waterfall, wait_until="domcontentloaded", timeout=120000)
            time.sleep(12)
            body = page.inner_text("body")
            if "Elastic did not load properly" in body or "Refresh the page" in body:
                print("bootstrap_or_chunk_error")
                try:
                    page.get_by_role("button", name="Reload").click(timeout=2000)
                except Exception:
                    try:
                        page.get_by_role("button", name="Refresh page").click(timeout=2000)
                    except Exception:
                        page.reload(wait_until="networkidle")
                time.sleep(8)
                body = page.inner_text("body")
                if "Elastic did not load properly" in body or "Refresh the page" in body:
                    continue

            for sel in [
                '[data-test-subj*="waterfall"] button[aria-expanded="false"]',
                '.euiAccordion__button[aria-expanded="false"]',
                'button[aria-label*="Expand"]',
            ]:
                btns = page.locator(sel)
                for i in range(min(btns.count(), 40)):
                    try:
                        btns.nth(i).click(timeout=500)
                    except Exception:
                        pass
            try:
                page.get_by_text("LegacyShipmentService", exact=False).first.scroll_into_view_if_needed(
                    timeout=5000
                )
            except Exception:
                pass
            for sel in ['button[aria-label="Close"]', '[data-test-subj="euiFlyoutCloseButton"]']:
                try:
                    page.locator(sel).first.click(timeout=1000)
                except Exception:
                    pass
            page.keyboard.press("Escape")
            time.sleep(1)
            body = page.inner_text("body")
            if "LegacyShipmentService" in body and "Refresh the page" not in body:
                ok = True
                break

        (ROOT / "results/vb-waterfall-page-snippet.txt").write_text(body[:8000])
        (ROOT / "results/vb-waterfall-console-errors.txt").write_text("\n".join(console_errs[-50:]))
        meta = {
            "source": "kibana-apm-trace-view",
            "trace_id": trace_id,
            "transaction_id": tx_id,
            "span_id": span_id,
            "timestamp": ts,
            "has_legacy_spans": "LegacyShipmentService" in body,
            "refresh_error": ("Refresh the page" in body) or ("Elastic did not load properly" in body),
            "url": waterfall,
            "ok": ok,
        }
        (ROOT / "results/vb-waterfall-capture-meta.json").write_text(json.dumps(meta, indent=2))
        print(json.dumps(meta))

        if ok:
            try:
                loc = page.locator('[data-test-subj*="waterfall"]').first
                if loc.count() > 0:
                    loc.screenshot(path=str(path))
                else:
                    page.screenshot(path=str(path), full_page=True)
            except Exception:
                page.screenshot(path=str(path), full_page=True)
            print("wrote", path, path.stat().st_size, "OK")
        else:
            fail = out / "16-vb-waterfall-kibana-chunk-error.png"
            page.screenshot(path=str(fail), full_page=True)
            print("FAILED wrote", fail)

        browser.close()
        return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
