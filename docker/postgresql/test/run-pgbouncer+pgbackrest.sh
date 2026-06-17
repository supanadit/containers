#!/bin/bash
# test/run-pgbouncer+pgbackrest.sh — Verify both features working together
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/compose.pgbouncer+pgbackrest.yaml"
SERVICE="postgresql"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== PgBouncer + pgBackRest Combined Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

echo ""
echo "Test 1: pg_isready"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -U postgres
echo "  PASS"

echo ""
echo "Test 2: pgbouncer process running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "pgbouncer" > /dev/null || { echo "  FAIL: pgbouncer process not found"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: Query through PgBouncer"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -tA -c "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1' through pgbouncer, got '$result'"; exit 1; }

echo ""
echo "Test 4: pgbackrest stanza check (as postgres user)"
docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" pgbackrest --stanza=default check 2>&1 || { echo "  FAIL: pgbackrest check failed"; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: pgbackrest stanza info (as postgres user)"
docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" pgbackrest --stanza=default info 2>&1 || { echo "  FAIL: pgbackrest info failed"; exit 1; }
echo "  PASS"

echo ""
echo "Test 6: SHOW POOLS via PgBouncer still works with pgbackrest enabled"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -d pgbouncer -tA -c "SHOW POOLS;" 2>/dev/null)
echo "$result" | grep -q "postgres" || { echo "  FAIL: SHOW POOLS failed when pgbackrest is also enabled"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL COMBINED TESTS PASSED ==="
