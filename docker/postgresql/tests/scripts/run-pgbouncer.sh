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

# A refused connection only says "port closed"; the reason lives in the
# container (pgbouncer's own logfile plus the ezx per-node logs), so a bare
# exit code is undiagnosable. Dump that state before failing.
dump_diagnostics() {
  echo "  --- diagnostics ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -a pgbouncer 2>&1 || echo "  (no pgbouncer process)"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -h localhost -p 6432 -U postgres 2>&1 || true
  echo "  --- pgbouncer.log ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" tail -40 /var/log/pgbouncer/pgbouncer.log 2>&1 || true
  echo "  --- /opt/containers/logs/pgbouncer.log ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" tail -40 /opt/containers/logs/pgbouncer.log 2>&1 || true
  echo "  --- /opt/containers/logs/pgbouncer-userlist.log ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" tail -20 /opt/containers/logs/pgbouncer-userlist.log 2>&1 || true
  echo "  --- compose logs ---"
  docker compose -f "$COMPOSE_FILE" logs --no-color --tail=40 "$SERVICE" 2>&1 || true
}

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
echo "Test 2: PgBouncer accepting connections on 6432"
# The process can exist without its listener: pgbouncer loads auth_file at
# startup and exits if the userlist is not there yet, so poll the port itself
# rather than a pid. pg_isready treats any server response (including an auth
# request) as "accepting connections".
ready=false
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -h localhost -p 6432 -U postgres > /dev/null 2>&1 \
    && { ready=true; break; }
  sleep 1
done
$ready || { echo "  FAIL: pgbouncer is not listening on 6432"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: SHOW POOLS via PgBouncer admin interface"
# Keep psql's stderr: discarding it turns an auth failure into a bare exit 2.
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -d pgbouncer -tA -c "SHOW POOLS;" 2>&1) \
  || { echo "  FAIL: SHOW POOLS could not connect"; echo "  output: $result"; dump_diagnostics; exit 1; }
echo "$result" | grep -q "postgres" || { echo "  FAIL: SHOW POOLS did not return pools"; echo "  output: $result"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: Query through PgBouncer"
result=$(docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -tA -c "SELECT 1;" 2>&1 | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1', got '$result'"; dump_diagnostics; exit 1; }

echo ""
echo "Test 5: Connection count via PgBouncer SHOW STATS"
docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=testpass "$SERVICE" psql -h localhost -p 6432 -U postgres -d pgbouncer -tA -c "SHOW STATS;" > /dev/null || { echo "  FAIL: SHOW STATS failed"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL PGBOUNCER TESTS PASSED ==="
