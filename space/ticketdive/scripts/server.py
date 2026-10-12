#!/usr/bin/env python3
"""
TicketDive HTTP API Server
Runs on Python 3 standard library with zero external dependencies.
Supports:
- GET /health
- GET /api/events/<eventId>
- GET /api/events?url=<url>
- POST /api/events/parse (Body: {"url": "..."} or {"id": "..."})
"""

import sys
import os
import json
import time
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any

from parse_ticketdive import fetch_and_parse_event, normalize_event_input

CACHE: Dict[str, Dict[str, Any]] = {}
CACHE_TTL_SECONDS = 60  # Cache responses for 60s

class TicketDiveApiHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def _send_json_response(self, status_code: int, data: Dict[str, Any]):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path.rstrip("/")
        query_params = urllib.parse.parse_qs(parsed_url.query)

        if path == "" or path == "/health" or path == "/api/health":
            self._send_json_response(200, {
                "status": "ok",
                "service": "ticketdive-api-server",
                "timestamp": int(time.time() * 1000)
            })
            return

        # Handle /api/events?url=...
        if path == "/api/events" and "url" in query_params:
            target = query_params["url"][0]
            self._handle_event_request(target)
            return

        # Handle /api/events/<eventId>
        if path.startswith("/api/events/"):
            event_id = path[len("/api/events/"):]
            if not event_id:
                self._send_json_response(400, {"error": "Missing event ID"})
                return
            self._handle_event_request(event_id)
            return

        self._send_json_response(404, {"error": "Not Found", "path": self.path})

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path.rstrip("/")

        if path in ("/api/events/parse", "/api/parse"):
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length <= 0:
                self._send_json_response(400, {"error": "Empty request body"})
                return

            body_bytes = self.rfile.read(content_length)
            try:
                payload = json.loads(body_bytes.decode("utf-8"))
            except Exception:
                self._send_json_response(400, {"error": "Invalid JSON body"})
                return

            target = payload.get("url") or payload.get("id") or payload.get("eventId")
            if not target:
                self._send_json_response(400, {"error": "Missing 'url' or 'id' in request body"})
                return

            self._handle_event_request(target)
            return

        self._send_json_response(404, {"error": "Not Found", "path": self.path})

    def _handle_event_request(self, target: str):
        now = time.time()
        try:
            norm = normalize_event_input(target)
            cache_key = norm["eventId"] or norm["targetUrl"]

            if cache_key in CACHE:
                cached_entry = CACHE[cache_key]
                if now - cached_entry["cached_at"] < CACHE_TTL_SECONDS:
                    self._send_json_response(200, {
                        "success": True,
                        "cached": True,
                        "data": cached_entry["data"]
                    })
                    return

            data = fetch_and_parse_event(target)
            CACHE[cache_key] = {
                "cached_at": now,
                "data": data
            }

            self._send_json_response(200, {
                "success": True,
                "cached": False,
                "data": data
            })
        except Exception as e:
            self._send_json_response(500, {
                "success": False,
                "error": str(e)
            })

    def log_message(self, format, *args):
        sys.stderr.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {args[0]} {args[1]} {args[2]}\n")

def run(port: int = 8787):
    server_address = ("", port)
    httpd = HTTPServer(server_address, TicketDiveApiHandler)
    print(f"TicketDive API Server listening on http://localhost:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()

if __name__ == "__main__":
    port_env = os.environ.get("PORT", "8787")
    run(port=int(port_env))
