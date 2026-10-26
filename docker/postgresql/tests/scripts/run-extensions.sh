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

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

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
