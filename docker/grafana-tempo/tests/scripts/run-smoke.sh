#!/bin/bash
# tests/scripts/run-smoke.sh — Tempo smoke test: the single binary reports ready,
# exports its own metrics, runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="tempo"

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

ready() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:3200/ready; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 600
wait_until "Tempo /ready" 120 ready

echo ""
echo "Test 1: Tempo reports itself ready"
ready | grep -q ready || fail "/ready"
echo "  PASS"

echo ""
echo "Test 2: Tempo exports its own metrics"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:3200/metrics | grep -qE '^tempo_' \
  || fail "no tempo metrics"
echo "  PASS"

echo ""
echo "Test 3: tempo.yaml was generated into the config volume"
dc exec -T "$SERVICE" test -s /opt/containers/config/tempo.yaml || fail "no tempo.yaml"
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u tempo | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "tempo user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises Tempo"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
