#!/usr/bin/env python3
"""Capture APM demo screenshots after per-app ServiceName verification (last 15m)."""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_env() -> None:
    for line in (ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def main() -> int:
    load_env()
    kibana = os.environ["KIBANA_URL"].rstrip("/")
    api_key = os.environ["ES_API_KEY"]
    out = ROOT / "screenshots"
    out.mkdir(parents=True, exist_ok=True)

    ids = json.loads((ROOT / "results/service-name-check/sql-span-ids.json").read_text())
    trace_id = ids["trace.id"]
    tx_id = ids["transaction.id"]
    span_id = ids["span.id"]

    from playwright.sync_api import sync_playwright

    range_q = "rangeFrom=now-15m&rangeTo=now&environment=lab"
    inventory = f"{kibana}/app/apm/services?{range_q}"
    service_map = f"{kibana}/app/apm/services/ShipmentsWeb/service-map?{range_q}"
    waterfall = (
        f"{kibana}/app/apm/services/ShipmentsWeb/transactions/view"
        f"?{range_q}&transactionId={tx_id}&traceId={trace_id}"
        f"&transactionName=POST%20Checkout%2FIndex&transactionType=request"
    )
    sql_span = (
        f"{kibana}/app/apm/services/ShipmentsWeb/transactions/view"
        f"?{range_q}&transactionId={tx_id}&traceId={trace_id}"
        f"&spanId={span_id}&waterfallItemId={span_id}"
        f"&transactionName=POST%20Checkout%2FIndex&transactionType=request"
        f"&detailTab=stack_trace"
    )

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Scope ApiKey to Kibana host only — extra_http_headers leaks onto CDN
        # (kibana.estccdn.com) and breaks CORS / "Elastic did not load properly".
        from urllib.parse import urlparse

        kibana_host = urlparse(kibana).hostname or ""
        context = browser.new_context(viewport={"width": 1680, "height": 1100})

        def attach_auth(route):
            route.continue_(
                headers={
                    **route.request.headers,
                    "authorization": f"ApiKey {api_key}",
                    "kbn-xsrf": "true",
                }
            )

        context.route(f"https://{kibana_host}/**", attach_auth)
        page = context.new_page()

        def shot(path: Path) -> None:
            page.screenshot(path=str(path), full_page=True)
            print("wrote", path.name, path.stat().st_size)

        # (a) Service inventory
        print("capture inventory", inventory)
        page.goto(inventory, wait_until="networkidle", timeout=180000)
        time.sleep(5)
        shot(out / "10-service-inventory-last-15m.png")

        # (d) Service map
        print("capture service map", service_map)
        page.goto(service_map, wait_until="networkidle", timeout=180000)
        time.sleep(8)
        shot(out / "13-service-map-last-15m.png")

        # (b) Trace waterfall — expand only chevrons, then close any flyout
        print("capture waterfall", waterfall)
        page.goto(waterfall, wait_until="networkidle", timeout=180000)
        time.sleep(6)
        # Expand collapsed accordion/chevron controls in the waterfall only
        for sel in [
            '[data-test-subj*="waterfall"] button[aria-expanded="false"]',
            '.euiAccordion__button[aria-expanded="false"]',
            'button[aria-label*="Expand"]',
            'button[aria-label*="expand"]',
        ]:
            btns = page.locator(sel)
            for i in range(min(btns.count(), 30)):
                try:
                    btns.nth(i).click(timeout=800)
                except Exception:
                    pass
        # Close flyout/side panel if open so waterfall is fully visible
        for sel in [
            'button[aria-label="Close"]',
            'button[aria-label="Close this dialog"]',
            '[data-test-subj="euiFlyoutCloseButton"]',
            '.euiFlyout__closeButton',
        ]:
            try:
                page.locator(sel).first.click(timeout=1500)
                time.sleep(0.5)
            except Exception:
                pass
        # Press Escape to dismiss panels
        page.keyboard.press("Escape")
        time.sleep(1)
        # Scroll waterfall into view
        try:
            page.get_by_text("Timeline", exact=False).first.scroll_into_view_if_needed(timeout=5000)
        except Exception:
            pass
        try:
            page.get_by_text("TrackingApi", exact=False).first.scroll_into_view_if_needed(timeout=5000)
        except Exception:
            pass
        time.sleep(1)
        shot(out / "11-checkout-trace-waterfall-last-15m.png")

        # (c) SQL span with stacktrace — ensure Contoso frame visible
        print("capture sql stack", sql_span)
        page.goto(sql_span, wait_until="networkidle", timeout=180000)
        time.sleep(5)
        for tab in ["Stack trace", "Stack Trace"]:
            try:
                page.get_by_role("tab", name=tab).click(timeout=4000)
                time.sleep(1.5)
                break
            except Exception:
                continue
        for needle in [
            "ShipmentRepository",
            "RunSlowQuery",
            "Contoso.Shipments.Business",
            "WAITFOR",
        ]:
            try:
                page.get_by_text(needle, exact=False).first.scroll_into_view_if_needed(timeout=4000)
                break
            except Exception:
                continue
        time.sleep(1)
        shot(out / "12-slow-sql-span-stacktrace-last-15m.png")

        browser.close()

    print("SCREENSHOTS_DONE", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
