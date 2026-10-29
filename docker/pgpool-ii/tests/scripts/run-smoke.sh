#!/bin/bash
# tests/scripts/run-smoke.sh — PgPool-II bootstrap smoke test.
#
# Runs with SLEEP_MODE=true so the bootstrap completes (validation, directories,
# config generation) and ezx stays PID 1 without needing live backends.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="pgpool"

trap 'rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
# The image HEALTHCHECK needs a live backend, so it is disabled in smoke.yaml
# (sleep mode has none). `up --wait` errors out when the container has no
# healthcheck, so plain `up -d` plus the poll below is the wait.
docker compose -f "$COMPOSE_FILE" up -d

# --wait only guarantees PID 1 (ezx) is running; poll until the bootstrap has
# written pgpool.conf before asserting on generated files.
echo "Waiting for the bootstrap to generate pgpool.conf..."
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" test -s /opt/containers/config/pgpool.conf > /dev/null 2>&1 && break
  sleep 1
done

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
echo "Test 4: pool_passwd holds an AES entry (pg_enc, 0600)"
# pgpool authenticates to scram-sha-256 backends as a client, which requires the
# recoverable password, so the entry must be AES (pg_enc), never an md5 hash.
passwd_contents="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /opt/containers/config/pool_passwd)"
printf '%s' "$passwd_contents" | grep -qE '^postgres:AES[0-9A-Za-z+/=]+$' \
  || { echo "  FAIL: expected 'postgres:AES<base64>', got: $passwd_contents"; exit 1; }
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
