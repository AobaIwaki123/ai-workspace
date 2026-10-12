#!/usr/bin/env python3
"""
TicketDive URL Parser & Metadata Extractor
Zero external dependencies (uses standard library urllib, json, re).
"""

import sys
import re
import json
import urllib.request
import urllib.parse
from typing import Optional, Dict, Any

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

def normalize_event_input(raw: str) -> Dict[str, str]:
    """
    Normalizes an event input (URL, shortened URL, or event ID) into standard URLs and event ID.
    """
    raw = raw.strip()
    # Check if raw is already an event ID (letters, numbers, underscores, hyphens)
    if re.match(r"^[A-Za-z0-9_-]+$", raw):
        event_id = raw
        target_url = f"https://ticketdive.com/event/{event_id}"
    else:
        # It is a URL
        parsed = urllib.parse.urlparse(raw)
        path = parsed.path.strip("/")
        parts = path.split("/")
        if "event" in parts:
            idx = parts.index("event")
            # Might be /event/fc/:id or /event/:id
            if idx + 1 < len(parts) and parts[idx + 1] == "fc" and idx + 2 < len(parts):
                event_id = parts[idx + 2]
                target_url = f"https://ticketdive.com/event/fc/{event_id}"
            elif idx + 1 < len(parts):
                event_id = parts[idx + 1]
                target_url = f"https://ticketdive.com/event/{event_id}"
            else:
                event_id = parts[-1]
                target_url = raw
        elif parsed.netloc in ("t-dv.com", "www.t-dv.com"):
            event_id = parts[-1] if parts else ""
            target_url = f"https://ticketdive.com/event/{event_id}"
        else:
            event_id = parts[-1] if parts else ""
            target_url = raw

    return {
        "eventId": event_id,
        "targetUrl": target_url,
        "canonicalUrl": f"https://ticketdive.com/event/{event_id}",
        "shortUrl": f"https://t-dv.com/{event_id}"
    }

def fetch_and_parse_event(raw_input: str) -> Dict[str, Any]:
    """
    Fetches the TicketDive page and parses structured event data from __NEXT_DATA__.
    """
    norm = normalize_event_input(raw_input)
    target_url = norm["targetUrl"]

    req = urllib.request.Request(
        target_url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "ja,en-US;q=0.9,en;q=0.8"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            html = res.read().decode("utf-8", errors="replace")
    except Exception as e:
        raise RuntimeError(f"Failed to fetch {target_url}: {e}")

    # Extract __NEXT_DATA__
    match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if not match:
        raise ValueError("Could not find __NEXT_DATA__ in response HTML")

    try:
        next_data = json.loads(match.group(1))
    except Exception as e:
        raise ValueError(f"Failed to parse __NEXT_DATA__ JSON: {e}")

    page_props = next_data.get("props", {}).get("pageProps", {})
    superjson = page_props.get("__superjsonProps", {}).get("json", {})
    event_detail = superjson.get("eventDetail")

    if not event_detail:
        raise ValueError("eventDetail not found in pageProps JSON")

    event_info = event_detail.get("event", {})
    stages_info = event_detail.get("stages", [])
    ticket_info_list = event_detail.get("ticketInfoList", [])
    event_images = superjson.get("eventImages", [])

    # Format stage / schedule
    stages_parsed = []
    all_artists = {}
    for st in stages_info:
        stage_item = {
            "id": st.get("id"),
            "stageName": st.get("stageName"),
            "startAt": st.get("startStage"),
            "openAt": st.get("openVenue"),
            "venue": st.get("venue", {}),
            "artists": []
        }
        for art in st.get("artists", []):
            art_id = art.get("id")
            art_name = art.get("name")
            stage_item["artists"].append({"id": art_id, "name": art_name})
            if art_id and art_name:
                all_artists[art_id] = art_name
        stages_parsed.append(stage_item)

    # Format tickets
    ticket_groups = []
    for tg in ticket_info_list:
        group_item = {
            "id": tg.get("id"),
            "name": tg.get("name"),
            "receptionType": tg.get("receptionType"),
            "startApply": tg.get("startApply"),
            "endApply": tg.get("endApply"),
            "paymentChannels": tg.get("paymentChannels", []),
            "customize": tg.get("customize", []),
            "status": tg.get("status"),
            "types": []
        }
        for tt in tg.get("ticketTypes", []):
            type_item = {
                "id": tt.get("id"),
                "name": tt.get("name"),
                "detail": tt.get("detail"),
                "price": tt.get("price"),
                "fee": tt.get("fee"),
                "remainingRate": tt.get("remainingRate"),
                "isSoldOut": (tt.get("remainingRate") == 0 or tt.get("status") == "closed"),
                "status": tt.get("status"),
                "maxNumPerApply": tt.get("maxNumPerApply"),
                "prefix": tt.get("prefix")
            }
            group_item["types"].append(type_item)
        ticket_groups.append(group_item)

    # Images
    images = [img.get("imageSource") for img in event_images if img.get("imageSource")]

    return {
        "id": event_info.get("id"),
        "slug": norm["eventId"],
        "name": event_info.get("name"),
        "detail": event_info.get("detail"),
        "release": event_info.get("release"),
        "url": norm["canonicalUrl"],
        "shortUrl": norm["shortUrl"],
        "stages": stages_parsed,
        "artists": [{"id": k, "name": v} for k, v in all_artists.items()],
        "ticketGroups": ticket_groups,
        "images": images,
        "serverTime": page_props.get("serverTime"),
        "buildId": next_data.get("buildId")
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 parse_ticketdive.py <event_url_or_id>", file=sys.stderr)
        sys.exit(1)

    input_arg = sys.argv[1]
    try:
        result = fetch_and_parse_event(input_arg)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as err:
        print(json.dumps({"error": str(err)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
