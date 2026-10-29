#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal PostgreSQL smoke test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="postgresql"
# The server's Unix socket lives in the normalized run dir (PGRUN). libpq's
# compiled-in default is /tmp, so psql/pg_isready must be pointed at it
# explicitly — otherwise they cannot find the server.
PG_SOCKET="/opt/containers/run"

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

# --wait only guarantees PID 1 (ezx) is running; the first boot runs initdb and
# starts the server. Poll until it accepts connections before asserting.
echo "Waiting for PostgreSQL to accept connections..."
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -h "$PG_SOCKET" -U postgres > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: pg_isready"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -h "$PG_SOCKET" -U postgres
echo "  PASS"

echo ""
echo "Test 2: SELECT 1"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1', got '$result'"; exit 1; }

echo ""
echo "Test 3: PostgreSQL version"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SELECT version();" | grep -q "PostgreSQL" || { echo "  FAIL: version check"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: Server process running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "postgres" > /dev/null || { echo "  FAIL: no postgres process"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
