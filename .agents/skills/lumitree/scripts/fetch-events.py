#!/usr/bin/env python3
"""
fetch-events.py - Fetch and format public calendar events from lumitree API.
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone, timedelta

DEFAULT_BASE_URL = "https://lumitree.aooba.net"
JST = timezone(timedelta(hours=9))


def fetch_calendar_events(base_url: str, calendar_id: str, year: int, month: int) -> dict:
    url = f"{base_url.rstrip('/')}/api/v1/calendars/{urllib.parse.quote(calendar_id)}/events?year={year}&month={month}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "lumitree-agent/1.0", "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            if res.status != 200:
                raise RuntimeError(f"HTTP {res.status}: {res.reason}")
            data = json.loads(res.read().decode("utf-8"))
            return data
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"API request failed: HTTP {e.code} - {e.reason}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Failed to connect to {url}: {e.reason}") from e


def parse_datetime(dt_str: str) -> datetime:
    if not dt_str:
        return datetime.min.replace(tzinfo=JST)
    # ISO 8601 parsing (e.g. 2026-10-04T09:00:00+09:00 or 2026-10-04T00:00:00Z)
    clean_str = dt_str.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(clean_str)
        return dt.astimezone(JST)
    except ValueError:
        return datetime.min.replace(tzinfo=JST)


def format_markdown(calendar_info: dict, events: list, year: int, month: int) -> str:
    lines = []
    cal_title = calendar_info.get("title", "Unknown Calendar")
    cal_id = calendar_info.get("aliasCode", "")
    lines.append(f"# {cal_title} ({year}/{month:02d})")
    lines.append(f"- Calendar ID: `{cal_id}`")

    sns = calendar_info.get("snsLinks") or {}
    sns_parts = []
    for platform, url in sns.items():
        if url:
            sns_parts.append(f"[{platform}]({url})")
    if sns_parts:
        lines.append(f"- SNS: {' / '.join(sns_parts)}")

    lines.append("")
    lines.append("## イベント一覧")
    lines.append("")

    if not events:
        lines.append("指定期間のイベントはありません。")
        return "\n".join(lines)

    for i, ev in enumerate(events, 1):
        title = ev.get("title", "名称未定")
        start_at_raw = ev.get("startAt", "")
        start_dt = parse_datetime(start_at_raw)
        all_day = ev.get("allDay", False)
        
        if all_day:
            date_str = start_dt.strftime("%Y/%m/%d (終日)")
        else:
            date_str = start_dt.strftime("%Y/%m/%d %H:%M")

        location = ev.get("location", "").strip() or "未定 / 記載なし"
        url = ev.get("url", "")
        desc = (ev.get("description") or "").strip()

        lines.append(f"### {i}. {title}")
        lines.append(f"- 日時: {date_str}")
        lines.append(f"- 会場: {location}")
        if url:
            lines.append(f"- 詳細URL: {url}")
        if desc:
            # First 3 lines or 200 chars
            desc_summary = desc.split("\n")[0][:150]
            lines.append(f"- 概要: {desc_summary}")
        lines.append("")

    return "\n".join(lines).strip()


def format_text(calendar_info: dict, events: list, year: int, month: int) -> str:
    lines = []
    cal_title = calendar_info.get("title", "Unknown Calendar")
    cal_id = calendar_info.get("aliasCode", "")
    lines.append(f"[{cal_title}] ({year}/{month:02d}) イベント情報")
    lines.append(f"カレンダーID: {cal_id}")
    lines.append("-" * 40)

    if not events:
        lines.append("指定期間のイベントはありません。")
        return "\n".join(lines)

    for i, ev in enumerate(events, 1):
        title = ev.get("title", "名称未定")
        start_at_raw = ev.get("startAt", "")
        start_dt = parse_datetime(start_at_raw)
        all_day = ev.get("allDay", False)

        if all_day:
            date_str = start_dt.strftime("%m/%d (終日)")
        else:
            date_str = start_dt.strftime("%m/%d %H:%M")

        location = ev.get("location", "").strip() or "未定"
        url = ev.get("url", "")

        lines.append(f"{i}. {date_str} - {title}")
        lines.append(f"   会場: {location}")
        if url:
            lines.append(f"   詳細: {url}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Fetch events from lumitree TimeTree proxy API."
    )
    parser.add_argument(
        "calendar_id",
        help="Calendar ID (aliasCode), e.g. ilife_official or plus_newidol"
    )
    now_jst = datetime.now(JST)
    parser.add_argument(
        "--year",
        type=int,
        default=now_jst.year,
        help=f"Year to fetch (default: {now_jst.year})"
    )
    parser.add_argument(
        "--month",
        type=int,
        default=now_jst.month,
        help=f"Month to fetch (1-12, default: {now_jst.month})"
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "text", "json"],
        default="markdown",
        help="Output format (default: markdown)"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of events returned (0 = all)"
    )
    parser.add_argument(
        "--upcoming-only",
        action="store_true",
        help="Filter events to only those occurring from today onwards"
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help=f"lumitree API base URL (default: {DEFAULT_BASE_URL})"
    )

    args = parser.parse_args()

    try:
        data = fetch_calendar_events(args.base_url, args.calendar_id, args.year, args.month)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    calendar_info = data.get("calendar", {})
    events = data.get("events", [])

    # Sort events by startAt
    events.sort(key=lambda x: parse_datetime(x.get("startAt", "")))

    if args.upcoming_only:
        today_start = now_jst.replace(hour=0, minute=0, second=0, microsecond=0)
        events = [ev for ev in events if parse_datetime(ev.get("startAt", "")) >= today_start]

    if args.limit > 0:
        events = events[:args.limit]

    if args.format == "json":
        output_obj = {
            "calendar": calendar_info,
            "year": args.year,
            "month": args.month,
            "count": len(events),
            "events": events
        }
        print(json.dumps(output_obj, ensure_ascii=False, indent=2))
    elif args.format == "text":
        print(format_text(calendar_info, events, args.year, args.month))
    else:
        print(format_markdown(calendar_info, events, args.year, args.month))


if __name__ == "__main__":
    main()
