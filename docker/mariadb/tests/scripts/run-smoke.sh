#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal MariaDB smoke test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="mariadb"
MARIADB_SOCKET="/opt/containers/run/mysqld.sock"

# on_exit — on failure dump the compose logs and the app's own log files (most
# lifecycles send child output to /opt/containers/logs), then tear down.
on_exit() {
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo ">>> Failure: container logs"
    docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true
    for s in $(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null); do
      cid=$(docker compose -f "$COMPOSE_FILE" ps -aq "$s" 2>/dev/null | head -1)
      [ -n "$cid" ] || continue
      echo "=== app logs: $s"
      # Most lifecycles send child output to /opt/containers/logs instead of
      # stdout, and a crash leaves the container exited where exec cannot reach
      # it: docker cp reads the files out of the stopped container instead.
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null | tar -xO 2>/dev/null | tail -n 80
      echo "=== rendered config: $s"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null | tar -xO 2>/dev/null | head -80
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

# --wait only guarantees PID 1 (ezx) is running. On first boot a temporary
# socket-only server (skip-networking) runs the bootstrap SQL before the real
# server starts, so a socket ping answers too early. Only the real server
# accepts TCP, so wait for that.
echo "Waiting for MariaDB to accept TCP connections..."
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    mariadb -u root -ptestpass --skip-ssl -h 127.0.0.1 -N -e "SELECT 1;" > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: mariadb-admin ping"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb-admin --socket="$MARIADB_SOCKET" -u root -ptestpass --skip-ssl ping
echo "  PASS"

echo ""
echo "Test 2: SELECT 1"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb --socket="$MARIADB_SOCKET" -u root -ptestpass --skip-ssl -N -e "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1', got '$result'"; exit 1; }

echo ""
echo "Test 3: MariaDB version"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb --socket="$MARIADB_SOCKET" -u root -ptestpass --skip-ssl -N -e "SELECT VERSION();" | grep -q "MariaDB" || { echo "  FAIL: version check"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: Server process running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "mariadbd" > /dev/null || { echo "  FAIL: no mariadbd process"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
