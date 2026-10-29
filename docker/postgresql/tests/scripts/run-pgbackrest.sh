#!/bin/bash
# tests/scripts/run-pgbackrest.sh — Verify pgBackRest backup system
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/pgbackrest.yaml"
SERVICE="postgresql"
STANZA="${PGBACKREST_STANZA:-default}"
# The server's Unix socket lives in the normalized run dir (PGRUN). libpq's
# compiled-in default is /tmp, so psql/pg_isready must be pointed at it
# explicitly — otherwise they cannot find the server.
PG_SOCKET="/opt/containers/run"
# Where stanza-create writes its metadata (posix repo).
ARCHIVE_INFO="/opt/containers/backup/archive/$STANZA/archive.info"

trap 'rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

# pgBackRest parses every PGBACKREST_* environment variable as a CLI option, so
# the container's own config vars (PGBACKREST_ENABLE=true) turn into
# "environment contains invalid option 'enable'". Run it through the same
# clean-env wrapper the archive_command uses.
pgbackrest_clean() {
  docker compose -f "$COMPOSE_FILE" exec -T -u postgres "$SERVICE" \
    env -u PGBACKREST_ENABLE -u PGBACKREST_AUTO_ENABLE -u PGBACKREST_ARCHIVE_ENABLE \
    pgbackrest --config=/etc/pgbackrest.conf "$@"
}

# A failure must say why: the stanza-init oneshot runs in the background and its
# reason lands in the ezx node log / pgBackRest file log, not in the compose
# output that --wait shows.
dump_diagnostics() {
  echo "  --- pgbackrest-stanza-init log ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" tail -40 /opt/containers/logs/pgbackrest-stanza-init.log 2>&1 || true
  echo "  --- pgbackrest file log ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" sh -c 'ls -la /opt/containers/backup; tail -40 /opt/containers/backup/log/*.log 2>/dev/null' 2>&1 || true
  echo "  --- /etc/pgbackrest.conf ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /etc/pgbackrest.conf 2>&1 || true
  echo "  --- archive settings ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -h "$PG_SOCKET" -U postgres -tAc \
    "SELECT name || '=' || setting FROM pg_settings WHERE name IN ('archive_mode','archive_command','wal_level','cluster_name');" 2>&1 || true
  echo "  --- manual stanza-create (as postgres, clean env) ---"
  pgbackrest_clean --stanza="$STANZA" stanza-create --log-level-console=detail 2>&1 || true
  echo "  --- postgres log (archive-related) ---"
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" sh -c \
    'grep -iE "archive|pgbackrest" /opt/containers/logs/postgres.log | tail -20' 2>&1 || true
  echo "  --- compose logs ---"
  docker compose -f "$COMPOSE_FILE" logs --no-color --tail=40 "$SERVICE" 2>&1 || true
}

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
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c "grep -q '^\[global\]' /etc/pgbackrest.conf && grep -q '^\[$STANZA\]' /etc/pgbackrest.conf" || { echo "  FAIL: config missing required sections"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
# stanza-init is an ezx one-shot that runs after postgres is ready; give it
# time to create the stanza before asserting on it. Poll the archive.info
# metadata it writes: `pgbackrest info` returns 0 even for a missing stanza, so
# it is useless as a readiness gate (it made the old loop break instantly).
echo "Waiting for the pgBackRest stanza ($STANZA) to be created..."
stanza_ready=false
for _ in $(seq 1 60); do
  if docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" test -f "$ARCHIVE_INFO" > /dev/null 2>&1; then
    stanza_ready=true
    break
  fi
  sleep 1
done
if [ "$stanza_ready" != true ]; then
  echo "  FAIL: stanza metadata $ARCHIVE_INFO was never created"
  dump_diagnostics
  exit 1
fi
echo "  PASS"

echo ""
echo "Test 4: pgbackrest stanza check"
pgbackrest_clean --stanza="$STANZA" check 2>&1 || { echo "  FAIL: pgbackrest check failed"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: pgbackrest stanza info"
pgbackrest_clean --stanza="$STANZA" info 2>&1 || { echo "  FAIL: pgbackrest info failed"; dump_diagnostics; exit 1; }
echo "  PASS"

echo ""
echo "Test 6: Backup directory exists"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'test -d /opt/containers/backup' || { echo "  FAIL: backup directory missing"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL PGBACKREST TESTS PASSED ==="
