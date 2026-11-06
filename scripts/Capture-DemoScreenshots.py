#!/usr/bin/env python3
"""Capture Kibana demo screenshots into screenshots/ using API-key auth."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env"


def load_env() -> None:
    for line in ENV.read_text().splitlines():
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

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        import subprocess

        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "playwright"])
        subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"])
        from playwright.sync_api import sync_playwright

    pages = [
        ("01-apm-services.png", f"{kibana}/app/apm/services?rangeFrom=now-1h&rangeTo=now"),
        ("02-apm-traces.png", f"{kibana}/app/apm/traces?rangeFrom=now-1h&rangeTo=now"),
        ("03-apm-dependencies.png", f"{kibana}/app/apm/services?rangeFrom=now-1h&rangeTo=now"),
        ("04-alerting-rules.png", f"{kibana}/app/observability/alerts/rules"),
        ("05-slo.png", f"{kibana}/app/observability/slos"),
        ("06-alerts.png", f"{kibana}/app/observability/alerts"),
    ]

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            extra_http_headers={
                "Authorization": f"ApiKey {api_key}",
                "kbn-xsrf": "true",
            },
        )
        page = context.new_page()
        for name, url in pages:
            print("capture", name, url)
            page.goto(url, wait_until="networkidle", timeout=120000)
            time.sleep(4)
            dest = out / name
            page.screenshot(path=str(dest), full_page=True)
            print("wrote", dest, "bytes", dest.stat().st_size)
        browser.close()

    print("SCREENSHOTS_DONE", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
