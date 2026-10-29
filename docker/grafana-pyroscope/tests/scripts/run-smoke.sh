#!/bin/bash
# tests/scripts/run-smoke.sh — Pyroscope smoke test: the single binary reports
# ready, serves its UI, runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="pyroscope"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# wait_until <label> <attempts> <command...> — poll a probe until it succeeds.
wait_until() {
  local label="$1" attempts="$2"; shift 2
  for _ in $(seq 1 "$attempts"); do
    if "$@" > /dev/null 2>&1; then echo "  ready: $label"; return 0; fi
    sleep 2
  done
  fail "$label did not become ready"
}

trap 'echo ">>> Cleanup: bringing down compose"; dc down -v > /dev/null 2>&1 || true' EXIT

ready() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:4040/ready; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "Pyroscope /ready" 60 ready

echo ""
echo "Test 1: Pyroscope reports itself ready"
ready | grep -q ready || fail "/ready"
echo "  PASS"

echo ""
echo "Test 2: the HTTP UI is served"
dc exec -T "$SERVICE" curl -fsS -o /dev/null http://127.0.0.1:4040/ || fail "UI not served"
echo "  PASS"

echo ""
echo "Test 3: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 4: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u pyroscope | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "pyroscope user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 5: ezx is PID 1 and supervises Pyroscope"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
dc exec -T "$SERVICE" pgrep -x pyroscope > /dev/null || fail "no pyroscope process"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
