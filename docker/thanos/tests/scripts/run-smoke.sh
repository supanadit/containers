#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal Thanos query smoke test.
#
# The `query` component needs no object store, so it is the cheapest full-stack
# boot. Verifies the query API, readiness, non-root user, and ezx as PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="thanos"

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
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

# --wait only guarantees PID 1 (ezx) is running; poll until Thanos answers.
for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:10902/-/ready > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: Thanos query is ready"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" curl -fsS http://127.0.0.1:10902/-/ready > /dev/null
echo "  PASS"

echo ""
echo "Test 2: query API answers"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  curl -fsS "http://127.0.0.1:10902/api/v1/query?query=up" | grep -q '"status":"success"' \
  || { echo "  FAIL: query API"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: runs as the dedicated non-root user"
uid="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" id -u thanos | tr -d '[:space:]')"
[ "$uid" != "0" ] || { echo "  FAIL: thanos user is root"; exit 1; }
echo "  PASS (uid=$uid)"

echo ""
echo "Test 4: ezx is PID 1 and supervises Thanos"
pid1="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || { echo "  FAIL: PID 1 is '$pid1', want 'ezx'"; exit 1; }
echo "  PASS"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -x thanos > /dev/null \
  || { echo "  FAIL: no thanos process"; exit 1; }
echo "  PASS (thanos supervised)"

echo ""
echo "Test 5: a rotated log file is written by ezx"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" test -f /opt/containers/logs/thanos-query.log \
  || { echo "  FAIL: expected /opt/containers/logs/thanos-query.log"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
