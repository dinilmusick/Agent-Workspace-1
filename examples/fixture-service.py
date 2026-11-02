#!/usr/bin/env python3
"""Tiny HTTP service used only by the runtime orchestration regression tests."""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

if len(sys.argv) > 1 and sys.argv[1] == "--fail-once":
    marker = Path(sys.argv[2])
    if not marker.exists():
        marker.write_text("started", encoding="utf-8")
        raise SystemExit(17)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        payload = json.dumps({"service": os.environ.get("SERVICE_NAME"), "ok": True, "upstream_port": os.environ.get("UPSTREAM_PORT")}).encode()
        self.send_response(200 if self.path == "/health" else 404)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, message, *args):
        print(message % args, flush=True)

port = int(os.environ["PORT"])
print(f"fixture service {os.environ.get('SERVICE_NAME')} listening on {port}", flush=True)
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
