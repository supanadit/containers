#!/bin/bash
# tests/scripts/run-smoke.sh — PgPool-II bootstrap smoke test.
#
# Runs with SLEEP_MODE=true so the bootstrap completes (validation, directories,
# config generation) and ezx stays PID 1 without needing live backends.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="pgpool"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 120

echo ""
echo "Test 1: pgpool.conf is generated with pid_file_name set"
# pgpool's compiled-in default pid file (/var/run/pgpool/pgpool.pid) does not exist
# in this image, so pgpool aborts at startup unless pid_file_name is pointed at
# the normalized run dir.
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" grep -q "^pid_file_name = '/opt/containers/run/pgpool.pid'" \
  /opt/containers/config/pgpool.conf || { echo "  FAIL: pid_file_name missing or wrong"; exit 1; }
echo "  PASS"

echo ""
echo "Test 2: PGPOOL_CONFIG_* overrides are applied"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" grep -q "^max_pool = 7" \
  /opt/containers/config/pgpool.conf || { echo "  FAIL: max_pool override not applied"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: backends are rendered"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" grep -q "^backend_hostname0 = 'postgres-1'" \
  /opt/containers/config/pgpool.conf || { echo "  FAIL: backend 0 missing"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: pool_passwd is generated from pg_md5 (0600, postgres:md5...)"
passwd_contents="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /opt/containers/config/pool_passwd)"
printf '%s' "$passwd_contents" | grep -qE '^postgres:md5[0-9a-f]{32}$' \
  || { echo "  FAIL: unexpected pool_passwd content: $passwd_contents"; exit 1; }
perms="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" stat -c '%a' /opt/containers/config/pool_passwd)"
[ "$perms" = "600" ] || { echo "  FAIL: pool_passwd is $perms, want 600"; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: pool_hba.conf is generated"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" grep -q "^host.*md5" \
  /opt/containers/config/pool_hba.conf || { echo "  FAIL: pool_hba.conf missing rules"; exit 1; }
echo "  PASS"

echo ""
echo "Test 6: ezx is PID 1 and supervises the node"
pid1="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || { echo "  FAIL: PID 1 is '$pid1', want 'ezx'"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
