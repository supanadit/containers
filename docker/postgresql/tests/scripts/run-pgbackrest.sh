#!/bin/bash
# tests/scripts/run-pgbackrest.sh — Verify pgBackRest backup system
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/pgbackrest.yaml"
SERVICE="postgresql"
# The server's Unix socket lives in the normalized run dir (PGRUN). libpq's
# compiled-in default is /tmp, so psql/pg_isready must be pointed at it
# explicitly — otherwise they cannot find the server.
PG_SOCKET="/opt/containers/run"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== pgBackRest Test ==="
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
echo "Test 2: pgbackrest binary exists"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" which pgbackrest || { echo "  FAIL: pgbackrest binary not found"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: pgbackrest config has required sections"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'grep -q "^\[global\]" /etc/pgbackrest.conf && grep -q "^\[default\]" /etc/pgbackrest.conf' || { echo "  FAIL: config missing required sections"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: pgbackrest stanza check (as postgres user)"
docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" pgbackrest --stanza=default check 2>&1 || { echo "  FAIL: pgbackrest check failed"; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: pgbackrest stanza info (as postgres user)"
docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" pgbackrest --stanza=default info 2>&1 || { echo "  FAIL: pgbackrest info failed"; exit 1; }
echo "  PASS"

echo ""
echo "Test 6: Backup directory exists"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'test -d /opt/containers/backup' || { echo "  FAIL: backup directory missing"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL PGBACKREST TESTS PASSED ==="
