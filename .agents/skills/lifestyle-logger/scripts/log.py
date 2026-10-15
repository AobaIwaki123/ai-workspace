#!/usr/bin/env python3
"""
Lifestyle Log CLI / Helper.
Appends or updates daily structured lifestyle JSON logs.
"""

import argparse
import datetime
import json
import os
import sys

BASE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../../private/data/lifestyle-logs")
)


def get_daily_file(target_date: str) -> str:
    parts = target_date.split("-")
    if len(parts) != 3:
        raise ValueError(f"Invalid date format: {target_date}, expected YYYY-MM-DD")
    year, month = parts[0], parts[1]
    dir_path = os.path.join(BASE_DIR, year, month)
    os.makedirs(dir_path, exist_ok=True)
    return os.path.join(dir_path, f"{target_date}.json")


def load_daily_log(file_path: str, date_str: str) -> dict:
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {
        "$schema": "../../schema/lifestyle-log.schema.json",
        "date": date_str,
        "summary": "",
        "events": [],
        "decisions": [],
        "dialogue_topics": [],
    }


def save_daily_log(file_path: str, data: dict):
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def add_event(args):
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    date_str = args.date or now.strftime("%Y-%m-%d")
    file_path = get_daily_file(date_str)
    data = load_daily_log(file_path, date_str)

    evt_time = args.timestamp or now.isoformat()
    evt_id = f"evt-{date_str.replace('-', '')}-{len(data['events']) + 1:02d}"

    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []

    event_obj = {
        "id": evt_id,
        "timestamp": evt_time,
        "category": args.category,
        "location": args.location or "",
        "title": args.title,
        "details": args.details,
        "tags": tags,
    }
    if args.metrics:
        try:
            event_obj["metrics"] = json.loads(args.metrics)
        except Exception:
            pass

    data["events"].append(event_obj)
    if args.summary:
        data["summary"] = args.summary

    save_daily_log(file_path, data)
    print(f"Added event [{evt_id}] to {file_path}")


def add_decision(args):
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    date_str = args.date or now.strftime("%Y-%m-%d")
    file_path = get_daily_file(date_str)
    data = load_daily_log(file_path, date_str)

    dec_time = args.timestamp or now.isoformat()
    dec_id = f"dec-{date_str.replace('-', '')}-{len(data['decisions']) + 1:02d}"

    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []

    decision_obj = {
        "id": dec_id,
        "timestamp": dec_time,
        "topic": args.topic,
        "context": args.context,
        "decision": args.decision,
        "tags": tags,
    }
    data["decisions"].append(decision_obj)
    save_daily_log(file_path, data)
    print(f"Added decision [{dec_id}] to {file_path}")


def add_topic(args):
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    date_str = args.date or now.strftime("%Y-%m-%d")
    file_path = get_daily_file(date_str)
    data = load_daily_log(file_path, date_str)

    topic_id = f"dia-{date_str.replace('-', '')}-{len(data['dialogue_topics']) + 1:02d}"
    takeaways = [t.strip() for t in args.takeaways.split(";") if t.strip()]
    notes = (
        [n.strip() for n in args.notes.split(",") if n.strip()] if args.notes else []
    )

    topic_obj = {
        "id": topic_id,
        "topic": args.topic,
        "takeaways": takeaways,
        "notes_synced": notes,
    }
    data["dialogue_topics"].append(topic_obj)
    save_daily_log(file_path, data)
    print(f"Added topic [{topic_id}] to {file_path}")


def main():
    parser = argparse.ArgumentParser(description="Lifestyle Logger CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Event parser
    ep = subparsers.add_parser("event", help="Add a physical or notable event")
    ep.add_argument("--date", help="Date YYYY-MM-DD")
    ep.add_argument("--timestamp", help="ISO 8601 timestamp")
    ep.add_argument(
        "--category",
        choices=[
            "fieldwork",
            "exercise",
            "culture",
            "communication",
            "rest",
            "work",
            "other",
        ],
        default="other",
    )
    ep.add_argument("--location", help="Location name")
    ep.add_argument("--title", required=True, help="Title of event")
    ep.add_argument("--details", required=True, help="Details of event")
    ep.add_argument("--tags", help="Comma separated tags")
    ep.add_argument("--metrics", help="JSON string for metrics")
    ep.add_argument("--summary", help="Set day summary")
    ep.set_defaults(func=add_event)

    # Decision parser
    dp = subparsers.add_parser("decision", help="Add a key decision")
    dp.add_argument("--date", help="Date YYYY-MM-DD")
    dp.add_argument("--timestamp", help="ISO 8601 timestamp")
    dp.add_argument("--topic", required=True, help="Decision topic")
    dp.add_argument("--context", required=True, help="Background context")
    dp.add_argument("--decision", required=True, help="Determined decision")
    dp.add_argument("--tags", help="Comma separated tags")
    dp.set_defaults(func=add_decision)

    # Topic parser
    tp = subparsers.add_parser("topic", help="Add dialogue topic / takeaways")
    tp.add_argument("--date", help="Date YYYY-MM-DD")
    tp.add_argument("--topic", required=True, help="Dialogue topic title")
    tp.add_argument(
        "--takeaways", required=True, help="Semicolon separated takeaways"
    )
    tp.add_argument("--notes", help="Comma separated paths to synced notes")
    tp.set_defaults(func=add_topic)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
