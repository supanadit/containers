#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal Prometheus smoke test.
#
# Verifies the container boots with the bundled default config, serves the API,
# is scraped-ready, runs as the dedicated non-root user, and keeps ezx as PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="prometheus"

# on_exit — on failure dump the compose logs and the app's own log files (most
# lifecycles send child output to /opt/containers/logs), then tear down.
on_exit() {
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo ">>> Failure: container logs"
    docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true
    for s in $(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null); do
      echo "=== app logs: $s"
      docker compose -f "$COMPOSE_FILE" exec -T "$s" sh -c 'tail -n 60 /opt/containers/logs/*.log' 2>/dev/null || true
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
}
trap on_exit EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

# --wait only guarantees PID 1 (ezx) is running; poll until Prometheus answers.
for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:19090/-/ready > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: Prometheus is ready"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" curl -fsS http://127.0.0.1:9090/-/ready > /dev/null
echo "  PASS"

echo ""
echo "Test 2: /api/v1/status/config returns the loaded config"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  curl -fsS http://127.0.0.1:9090/api/v1/status/config | grep -q '"status":"success"' \
  || { echo "  FAIL: config status endpoint"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: Prometheus build info"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  curl -fsS http://127.0.0.1:9090/api/v1/status/buildinfo | grep -q '"version"' \
  || { echo "  FAIL: buildinfo"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: runs as the dedicated non-root user"
uid="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" id -u prometheus | tr -d '[:space:]')"
[ "$uid" != "0" ] || { echo "  FAIL: prometheus user is root"; exit 1; }
echo "  PASS (uid=$uid)"

echo ""
echo "Test 5: ezx is PID 1 and supervises Prometheus"
pid1="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || { echo "  FAIL: PID 1 is '$pid1', want 'ezx'"; exit 1; }
echo "  PASS"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -x prometheus > /dev/null \
  || { echo "  FAIL: no prometheus process"; exit 1; }
echo "  PASS (prometheus supervised)"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
