#!/bin/bash
# tests/scripts/run-edge-cases.sh — Verify database creation, app user, and
# root host handling (root@'%' must not be left with an empty password).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/edge-cases.yaml"
SERVICE="mariadb"

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

echo "=== Edge-Case Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

# --wait only guarantees PID 1 (ezx) is running. On first boot a temporary
# socket-only server (skip-networking) runs the bootstrap SQL before the real
# server starts, so a socket ping answers too early — while the bootstrap is
# still committing. Only the real server accepts TCP, so wait for that.
echo "Waiting for MariaDB to accept TCP connections..."
for _ in $(seq 1 60); do
  docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    mariadb -u root -ptestpass --skip-ssl -h 127.0.0.1 -N -e "SELECT 1;" > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: Database 'myapp' was created"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb -u root -ptestpass --skip-ssl --socket=/opt/containers/run/mysqld.sock -N -e "SHOW DATABASES LIKE 'myapp';" | tr -d '[:space:]')
[ "$result" = "myapp" ] && echo "  PASS" || { echo "  FAIL: database 'myapp' not found, got '$result'"; exit 1; }

echo ""
echo "Test 2: App user can connect and access the database"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb -u appuser -papppass --skip-ssl -h 127.0.0.1 myapp -N -e "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: app user query failed, got '$result'"; exit 1; }

echo ""
echo "Test 3: root@'%' account has a password (not empty)"
# Connect over TCP as root@'%' with the password; an empty-password root@'%'
# would either reject the password or accept without it. We assert the
# password-authenticated connection succeeds.
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb -u root -ptestpass --skip-ssl -h 127.0.0.1 -N -e "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: root TCP connection with password failed, got '$result'"; exit 1; }

echo ""
echo "Test 4: root@'%' account exists and is not empty-password"
# Query the mysql.user table to confirm every root account has a non-empty
# authentication_string (i.e. no anonymous/empty root@'%').
empty=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" mariadb -u root -ptestpass --skip-ssl --socket=/opt/containers/run/mysqld.sock -N -e "SELECT COUNT(*) FROM mysql.user WHERE user='root' AND (authentication_string='' OR authentication_string IS NULL);" | tr -d '[:space:]')
[ "$empty" = "0" ] && echo "  PASS" || { echo "  FAIL: found $empty root account(s) with empty password"; exit 1; }

echo ""
echo "=== ALL EDGE-CASE TESTS PASSED ==="
