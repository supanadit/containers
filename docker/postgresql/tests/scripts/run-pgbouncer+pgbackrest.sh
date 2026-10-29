#!/bin/bash
# tests/scripts/run-pgbouncer+pgbackrest.sh — Verify both features working together
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/pgbouncer+pgbackrest.yaml"
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

echo "=== PgBouncer + pgBackRest Combined Test ==="
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
echo "Test 2: pgbouncer process running"
# ezx starts pgbouncer only after the database reports ready, which is later
# than the socket accepting connections — poll instead of a single shot.
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "pgbouncer" > /dev/null 2>&1 && break
  sleep 1
done
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "pgbouncer" > /dev/null \
  || { echo "  FAIL: pgbouncer process not found"; docker compose -f "$COMPOSE_FILE" logs "$SERVICE" | tail -20; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: Query through PgBouncer"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -tA -c "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1' through pgbouncer, got '$result'"; exit 1; }

echo ""
# stanza-init is an ezx one-shot that runs after postgres is ready; give it
# time to create the stanza before asserting on it.
echo "Waiting for the pgBackRest stanza to be created..."
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" pgbackrest --stanza=default info > /dev/null 2>&1 && break
  sleep 1
done

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
echo "$result" | grep -c "postgres" > /dev/null || { echo "  FAIL: SHOW POOLS failed when pgbackrest is also enabled"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL COMBINED TESTS PASSED ==="
