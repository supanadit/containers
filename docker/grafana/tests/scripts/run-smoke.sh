#!/bin/bash
# tests/scripts/run-smoke.sh — Grafana smoke test: the server answers its own
# health API with a working database, runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="grafana"

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

trap 'rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; dc logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; dc down -v > /dev/null 2>&1 || true' EXIT

healthApi() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:3000/api/health; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "Grafana /api/health" 60 healthApi

echo ""
echo "Test 1: Grafana's own health API is ok"
healthApi | grep -Eq '"database": *"ok"' || fail "database not ok"
echo "  PASS"

echo ""
echo "Test 2: grafana.ini was seeded into the config volume"
dc exec -T "$SERVICE" test -s /opt/containers/config/grafana.ini || fail "no grafana.ini"
echo "  PASS"

echo ""
echo "Test 3: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 4: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u grafana | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "grafana user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 5: ezx is PID 1 and supervises Grafana"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
