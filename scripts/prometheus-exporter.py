#!/usr/bin/env python3
# scripts/prometheus-exporter.py — OpenClaw Self-Healing Metrics Exporter
#
# Exposes recovery metrics in Prometheus text format.
# Default port: 9090 (override with OPENCLAW_METRICS_PORT or argv[1]).
#
# Usage:
#   python3 scripts/prometheus-exporter.py          # foreground, port 9090
#   python3 scripts/prometheus-exporter.py 8080     # custom port
#   bash scripts/start-metrics-exporter.sh start    # managed daemon
#
# Endpoints:
#   GET /metrics  — Prometheus text exposition format (v0.0.4)
#   GET /health   — Liveness check (returns "OK")
#
# Metrics exported:
#   openclaw_gateway_healthy                  gauge    1 if HTTP 200, 0 otherwise
#   openclaw_recovery_attempts                gauge    Total Level-3 recovery attempts
#   openclaw_recovery_success                 gauge    Successful recoveries
#   openclaw_recovery_failed                  gauge    Failed recoveries
#   openclaw_recovery_rate_percent            gauge    Success rate 0-100
#   openclaw_last_recovery_duration_seconds   gauge    Last recovery duration
#   openclaw_last_recovery_success            gauge    1=success, 0=failed
#   openclaw_last_recovery_timestamp_seconds  gauge    Last recovery Unix timestamp

import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = int(os.environ.get("OPENCLAW_METRICS_PORT",
           sys.argv[1] if len(sys.argv) > 1 else 9090))
GATEWAY_URL = os.environ.get("OPENCLAW_GATEWAY_URL", "http://localhost:18789/")
MEMORY_DIR = Path(os.environ.get(
    "OPENCLAW_MEMORY_DIR", Path.home() / "openclaw" / "memory"))
METRICS_FILE = MEMORY_DIR / ".emergency-recovery-metrics.json"
GATEWAY_CACHE_TTL = 10  # seconds between live gateway health checks

_gw_cache: dict = {"v": -1, "ts": 0}


def check_gateway_health() -> int:
    """Returns 1 if gateway is healthy, 0 otherwise (cached for GATEWAY_CACHE_TTL s)."""
    now = time.time()
    if now - _gw_cache["ts"] < GATEWAY_CACHE_TTL:
        return _gw_cache["v"]
    try:
        r = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
             "--max-time", "5", GATEWAY_URL],
            capture_output=True, text=True, timeout=8
        )
        val = 1 if r.stdout.strip() == "200" else 0
    except Exception:
        val = 0
    _gw_cache.update({"v": val, "ts": now})
    return val


def read_recovery_records() -> list:
    """Parse JSONL metrics file written by emergency-recovery-v2.sh."""
    records = []
    if not METRICS_FILE.exists():
        return records
    try:
        with open(METRICS_FILE) as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    records.append(json.loads(raw))
                except json.JSONDecodeError:
                    pass
    except OSError:
        pass
    return records


def build_prometheus_metrics() -> str:
    """Returns a Prometheus text format string."""
    out: list[str] = []

    def g(name: str, help_text: str, value) -> None:
        out.append(f"# HELP {name} {help_text}")
        out.append(f"# TYPE {name} gauge")
        out.append(f"{name} {value}")

    # 1. Gateway liveness
    g("openclaw_gateway_healthy",
      "1 if OpenClaw gateway returns HTTP 200, 0 otherwise",
      check_gateway_health())

    # 2. Recovery counters from metrics file
    records = read_recovery_records()
    total = len(records)
    successful = sum(1 for r in records if r.get("result") == "true")
    failed = total - successful
    rate = round(successful / total * 100, 1) if total > 0 else 0.0

    g("openclaw_recovery_attempts",
      "Total Level-3 emergency recovery attempts since install", total)
    g("openclaw_recovery_success",
      "Successful Level-3 emergency recovery attempts", successful)
    g("openclaw_recovery_failed",
      "Failed Level-3 emergency recovery attempts", failed)
    g("openclaw_recovery_rate_percent",
      "Autonomous recovery success rate (0-100)", rate)

    # 3. Last recovery detail
    if records:
        last = records[-1]
        g("openclaw_last_recovery_duration_seconds",
          "Duration of the last emergency recovery attempt in seconds",
          float(last.get("duration", 0)))
        g("openclaw_last_recovery_success",
          "1 if the last recovery succeeded, 0 if it failed",
          1 if last.get("result") == "true" else 0)
        g("openclaw_last_recovery_timestamp_seconds",
          "Unix timestamp when the last recovery attempt started",
          int(last.get("timestamp", 0)))

    return "\n".join(out) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/metrics":
            try:
                body = build_prometheus_metrics().encode("utf-8")
                self.send_response(200)
                self.send_header(
                    "Content-Type",
                    "text/plain; version=0.0.4; charset=utf-8"
                )
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except Exception as exc:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(exc).encode())
        elif self.path in ("/health", "/"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args) -> None:  # silence access logs
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), MetricsHandler)
    print(f"OpenClaw Metrics Exporter — :{PORT}/metrics", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
