#!/usr/bin/env python3
"""
Unified AI Gateway for WSL2 (Port 8080).
Eliminates the need for multiple Windows port-forwarding/firewall rules.
- /api/benchmarks, /v1/models/benchmarks -> serves data/benchmarks.json directly (< 0.5ms)
- /v1/*, /health, /* -> transparently proxies to internal llama-server (127.0.0.1:8081) with full SSE streaming support.
"""
import http.server
import socketserver
import urllib.request
import urllib.error
import json
import sys
from pathlib import Path

PUBLIC_PORT = 8080
LLAMA_INTERNAL_URL = "http://127.0.0.1:8081"
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_FILE = BASE_DIR / "data" / "benchmarks.json"

class GatewayHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, DELETE")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        # 1. Internal Benchmarks Endpoint
        if self.path in ["/api/benchmarks", "/v1/models/benchmarks"]:
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
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            return

        # 2. Transparent Proxy to llama-server (GET)
        self._proxy_request("GET")

    def do_POST(self):
        self._proxy_request("POST")

    def _proxy_request(self, method: str):
        target_url = f"{LLAMA_INTERNAL_URL}{self.path}"
        headers = {k: v for k, v in self.headers.items() if k.lower() != "host"}
        headers["Host"] = "127.0.0.1:8081"

        data = None
        if method == "POST":
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 0:
                data = self.rfile.read(content_length)

        req = urllib.request.Request(target_url, data=data, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                self.send_response(resp.status)
                for header, value in resp.getheaders():
                    if header.lower() not in ["server", "transfer-encoding"]:
                        self.send_header(header, value)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()

                # Stream response back to client in real-time
                while True:
                    chunk = resp.read(256)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            err_msg = json.dumps({"error": f"Gateway proxy error: {str(e)}"}).encode("utf-8")
            self.wfile.write(err_msg)

def run():
    socketserver.TCPServer.allow_reuse_address = True
    server = socketserver.TCPServer(("0.0.0.0", PUBLIC_PORT), GatewayHandler)
    print(f"[SUCCESS] Unified AI Gateway started on http://0.0.0.0:{PUBLIC_PORT}")
    print(f"  OpenAI API Endpoint:      http://192.168.11.15:{PUBLIC_PORT}/v1/chat/completions")
    print(f"  Benchmark JSON Metadata: http://192.168.11.15:{PUBLIC_PORT}/api/benchmarks")
    server.serve_forever()

if __name__ == "__main__":
    run()
