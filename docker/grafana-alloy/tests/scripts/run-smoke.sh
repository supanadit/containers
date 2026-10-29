#!/bin/bash
# tests/scripts/run-smoke.sh — Alloy smoke test: the agent reports ready, serves
# its own metrics, runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="alloy"

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

ready() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:12345/-/ready; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "Alloy /-/ready" 60 ready

echo ""
echo "Test 1: Alloy reports itself ready"
ready | grep -q 'Alloy is ready' || fail "/-/ready"
echo "  PASS"

echo ""
echo "Test 2: Alloy serves its own metrics"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:12345/metrics | grep -q 'alloy_build_info' \
  || fail "no alloy_build_info metric"
echo "  PASS"

echo ""
echo "Test 3: config.alloy was seeded into the config volume"
dc exec -T "$SERVICE" test -s /opt/containers/config/config.alloy || fail "no config.alloy"
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u alloy | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "alloy user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises Alloy"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
dc exec -T "$SERVICE" pgrep -x alloy > /dev/null || fail "no alloy process"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
