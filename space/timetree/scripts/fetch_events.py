#!/usr/bin/env python3
"""
TimeTree Public Calendar Event Fetcher
Usage:
    python3 fetch_events.py [calendar_id] [--json] [--year YYYY] [--month MM]

Example:
    python3 fetch_events.py ilife_official
    python3 fetch_events.py ilife_official --json
"""

import argparse
import datetime
import json
import re
import sys
import urllib.request


def fetch_calendar_events(calendar_id: str, year: int = None, month: int = None):
    base_url = f"https://timetreeapp.com/public_calendars/{calendar_id}"
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    # 1. Fetch initial HTML to get CSRF token and Session Cookie
    req = urllib.request.Request(
        base_url,
        headers={"User-Agent": user_agent},
    )
    try:
        resp = urllib.request.urlopen(req)
    except urllib.error.HTTPError as e:
        print(f"❌ Error fetching calendar page: HTTP {e.code} {e.reason}", file=sys.stderr)
        sys.exit(1)

    html = resp.read().decode("utf-8")
    cookies = resp.headers.get_all("Set-Cookie") or []
    cookie_str = "; ".join([c.split(";")[0] for c in cookies])

    csrf_match = re.search(r'<meta\s+name="csrf-token"\s+content="([^"]+)"', html)
    if not csrf_match:
        print("❌ Could not find CSRF token in page HTML.", file=sys.stderr)
        sys.exit(1)
    csrf_token = csrf_match.group(1)

    # 2. Build API request
    api_url = f"https://timetreeapp.com/api/v2/public_calendars/{calendar_id}/public_events"
    params = []
    if year:
        params.append(f"year={year}")
    if month:
        params.append(f"month={month}")
    if params:
        api_url += "?" + "&".join(params)

    headers = {
        "User-Agent": user_agent,
        "Accept": "application/json, text/plain, */*",
        "Referer": base_url,
        "Cookie": cookie_str,
        "X-CSRF-Token": csrf_token,
        "X-TimeTreeA": "web/2.1.0/1.0.0",
    }

    api_req = urllib.request.Request(api_url, headers=headers)
    try:
        api_resp = urllib.request.urlopen(api_req)
        return json.loads(api_resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        print(f"❌ Error calling TimeTree API: HTTP {e.code} {e.reason}\nBody: {body}", file=sys.stderr)
        sys.exit(1)


def format_timestamp(ts_ms):
    if not ts_ms:
        return "N/A"
    dt = datetime.datetime.fromtimestamp(ts_ms / 1000.0)
    return dt.strftime("%Y-%m-%d %H:%M")


def main():
    parser = argparse.ArgumentParser(description="Fetch events from TimeTree public calendar.")
    parser.add_argument("calendar_id", nargs="?", default="ilife_official", help="TimeTree public calendar ID/alias")
    parser.add_argument("--json", action="store_true", help="Output raw JSON response")
    parser.add_argument("--year", type=int, help="Filter year (e.g. 2026)")
    parser.add_argument("--month", type=int, help="Filter month (1-12)")

    args = parser.parse_args()

    data = fetch_calendar_events(args.calendar_id, year=args.year, month=args.month)

    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    events = data.get("public_events", [])
    print(f"📅 [{args.calendar_id}] Found {len(events)} events:")
    print("=" * 60)

    for idx, ev in enumerate(events, 1):
        title = ev.get("title", "(No Title)")
        start = format_timestamp(ev.get("start_at"))
        end = format_timestamp(ev.get("end_at"))
        location = ev.get("location") or "指定なし"
        desc = ev.get("description") or ""

        print(f"#{idx} {title}")
        print(f"   🕒 日時: {start} 〜 {end}")
        print(f"   📍 場所: {location}")
        if desc:
            short_desc = desc.strip().replace("\n", " ")[:80]
            print(f"   📝 詳細: {short_desc}...")
        print("-" * 60)


if __name__ == "__main__":
    main()
