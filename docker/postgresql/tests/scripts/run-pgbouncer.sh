#!/bin/bash
# tests/scripts/run-pgbouncer.sh — Verify PgBouncer connection pooling
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/pgbouncer.yaml"
SERVICE="postgresql"
# The server's Unix socket lives in the normalized run dir (PGRUN). libpq's
# compiled-in default is /tmp, so psql/pg_isready must be pointed at it
# explicitly — otherwise they cannot find the server.
PG_SOCKET="/opt/containers/run"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== PgBouncer Test ==="
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
echo "Test 1: pg_isready (direct to PostgreSQL)"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -h "$PG_SOCKET" -U postgres
echo "  PASS"

echo ""
echo "Test 2: PgBouncer process running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "pgbouncer" > /dev/null || { echo "  FAIL: pgbouncer process not found"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: SHOW POOLS via PgBouncer admin interface"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -d pgbouncer -tA -c "SHOW POOLS;" 2>/dev/null)
echo "$result" | grep -q "postgres" || { echo "  FAIL: SHOW POOLS did not return pools"; echo "  output: $result"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: Query through PgBouncer"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -tA -c "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1', got '$result'"; exit 1; }

echo ""
echo "Test 5: Connection count via PgBouncer SHOW STATS"
docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -d pgbouncer -tA -c "SHOW STATS;" > /dev/null 2>&1 || { echo "  FAIL: SHOW STATS failed"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL PGBOUNCER TESTS PASSED ==="
