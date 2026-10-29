#!/bin/bash
# tests/scripts/run-extensions.sh — Verify default extensions load correctly
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/extensions.yaml"
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
    for s in $(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null); do
      cid=$(docker compose -f "$COMPOSE_FILE" ps -aq "$s" 2>/dev/null | head -1)
      [ -n "$cid" ] || continue
      echo "=== $s: container log (tail 80)"
      docker compose -f "$COMPOSE_FILE" logs --no-color --tail 80 "$s" || true
      echo "=== $s: app log files"
      # Most lifecycles write child output to files under /opt/containers, and a
      # crash leaves the container exited where `exec` cannot reach it: docker cp
      # reads them out of the stopped container.
      docker cp "$cid:/opt/containers/." - 2>/dev/null \
        | tar -xO --wildcards '*.log' '*.out' 2>/dev/null | tail -n 120
      echo "=== $s: rendered config"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null \
        | tar -xO 2>/dev/null | head -80
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

echo "=== Extensions Test ==="
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
echo "Test 2: shared_preload_libraries contains pgaudit"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SHOW shared_preload_libraries;")
echo "$result" | grep -q "pgaudit" || { echo "  FAIL: pgaudit not in shared_preload_libraries"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: shared_preload_libraries contains pg_stat_statements"
echo "$result" | grep -q "pg_stat_statements" || { echo "  FAIL: pg_stat_statements not in shared_preload_libraries"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: pgaudit extension available"
count=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SELECT count(*) FROM pg_available_extensions WHERE name = 'pgaudit';" | tr -d '[:space:]')
[ "$count" = "1" ] || [ "$count" -ge "1" ] && echo "  PASS" || { echo "  FAIL: pgaudit extension not available"; exit 1; }

echo ""
echo "Test 5: pg_stat_statements extension available"
count=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SELECT count(*) FROM pg_available_extensions WHERE name = 'pg_stat_statements';" | tr -d '[:space:]')
[ "$count" = "1" ] || [ "$count" -ge "1" ] && echo "  PASS" || { echo "  FAIL: pg_stat_statements extension not available"; exit 1; }

echo ""
echo "Test 6: hypopg extension available"
count=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tA -c "SELECT count(*) FROM pg_available_extensions WHERE name = 'hypopg';" | tr -d '[:space:]')
[ "$count" = "1" ] || [ "$count" -ge "1" ] && echo "  PASS" || { echo "  FAIL: hypopg extension not available"; exit 1; }

echo ""
echo "=== ALL EXTENSIONS TESTS PASSED ==="
