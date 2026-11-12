#!/usr/bin/env python3
"""Capture evidence of LegacyShipmentService.* spans (waterfall or Discover fallback)."""
from __future__ import annotations

import os
import time
import urllib.parse
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
    path = out / "16-vb-legacyshipmentservice-waterfall.png"

    # Discover is more reliable with ApiKey auth than deep APM waterfall routes.
    kuery = 'service.name: "ShipmentsWeb" and span.name: LegacyShipmentService*'
    discover = (
        f"{kibana}/app/discover#/"
        f"?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),"
        f"time:(from:'2026-11-12T12:30:00.000Z',to:'2026-11-12T12:45:00.000Z'))"
        f"&_a=(columns:!(span.name,service.name,trace.id,transaction.id,@timestamp),"
        f"dataSource:(dataViewId:apm_static_data_view_id_default,type:dataView),"
        f"filters:!(),hideChart:!f,interval:auto,"
        f"query:(language:kuery,query:'{urllib.parse.quote(kuery)}'),"
        f"sort:!(!('@timestamp',desc)))"
    )

    # Also try APM transactions/view once Discover confirms data.
    trace_id = "8a7d68f66db3a5dd468cce7d95a0817b"
    tx_id = "c2a374dabb77eb8a"
    waterfall = (
        f"{kibana}/app/apm/services/ShipmentsWeb/transactions/view"
        f"?kuery=&rangeFrom=2026-11-12T12:30:00.000Z&rangeTo=2026-11-12T12:45:00.000Z"
        f"&environment=lab&transactionId={tx_id}&traceId={trace_id}"
        f"&transactionName=POST%20Checkout%2FIndex&transactionType=request"
    )

    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 1680, "height": 1200},
            extra_http_headers={
                "Authorization": f"ApiKey {api_key}",
                "kbn-xsrf": "true",
            },
        )
        page = context.new_page()

        def shot(label: str) -> bool:
            time.sleep(6)
            body = page.inner_text("body")
            print(label, "Legacy?" , "LegacyShipmentService" in body, "len", len(body))
            (ROOT / "results/vb-waterfall-page-snippet.txt").write_text(body[:5000])
            if "Refresh the page" in body and "LegacyShipmentService" not in body:
                return False
            page.screenshot(path=str(path), full_page=True)
            return "LegacyShipmentService" in body

        print("discover", discover[:120], "...")
        page.goto(discover, wait_until="networkidle", timeout=180000)
        ok = shot("discover")
        if not ok:
            print("waterfall fallback", waterfall)
            page.goto(waterfall, wait_until="networkidle", timeout=180000)
            for _ in range(3):
                time.sleep(5)
                if "Refresh the page" not in page.inner_text("body"):
                    break
                page.reload(wait_until="networkidle")
            for sel in [
                '[data-test-subj*="waterfall"] button[aria-expanded="false"]',
                '.euiAccordion__button[aria-expanded="false"]',
            ]:
                btns = page.locator(sel)
                for i in range(min(btns.count(), 40)):
                    try:
                        btns.nth(i).click(timeout=500)
                    except Exception:
                        pass
            ok = shot("waterfall")

        print("wrote", path, path.stat().st_size, "OK" if ok else "PARTIAL")
        browser.close()
    return 0 if path.exists() else 1


if __name__ == "__main__":
    raise SystemExit(main())
