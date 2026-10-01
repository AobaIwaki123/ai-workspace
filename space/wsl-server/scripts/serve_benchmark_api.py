#!/usr/bin/env python3
"""
Lightweight REST API server for serving benchmarks.json metadata.
Runs on port 8088 (or proxied via k8s Service).
Returns data/benchmarks.json in < 1ms with CORS enabled.
"""
import http.server
import socketserver
import json
from pathlib import Path
import sys

PORT = 8088
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_FILE = BASE_DIR / "data" / "benchmarks.json"

class BenchmarkAPIHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ["/api/benchmarks", "/v1/models/benchmarks", "/"]:
            if not DATA_FILE.exists():
                self.send_response(404)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error": "benchmarks.json not found"}')
                return

            with open(DATA_FILE, "r", encoding="utf-8") as f:
                content = f.read().encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

def run():
    server = socketserver.TCPServer(("0.0.0.0", PORT), BenchmarkAPIHandler)
    server.allow_reuse_address = True
    print(f"[SUCCESS] Benchmark JSON API serving on http://0.0.0.0:{PORT}/api/benchmarks")
    server.serve_forever()

if __name__ == "__main__":
    run()
