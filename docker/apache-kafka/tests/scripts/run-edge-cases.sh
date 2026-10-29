#!/bin/bash
# tests/scripts/run-edge-cases.sh — non-root runtime, ownership, KAFKA_CONFIG_*
# override, and restart idempotency.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/edge-cases.yaml"
SERVICE="kafka"

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
  rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; docker compose -f "$COMPOSE_FILE" logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
}
trap on_exit EXIT

echo "=== Edge-Case Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

echo ""
echo "Test 1: broker runs as non-root kafka user"
owner=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    ps -o user= -C java | head -1 | tr -d '[:space:]')
[ "$owner" = "kafka" ] && echo "  PASS" || { echo "  FAIL: java runs as '$owner'"; exit 1; }

echo ""
echo "Test 2: data directory owned by kafka"
downer=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    stat -c '%U' /opt/containers/data | tr -d '[:space:]')
[ "$downer" = "kafka" ] && echo "  PASS" || { echo "  FAIL: data dir owner '$downer'"; exit 1; }

echo ""
echo "Test 3: KAFKA_CONFIG_* override applied to server.properties"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    grep -q '^auto.create.topics.enable=false$' /opt/containers/config/server.properties \
    && echo "  PASS" || { echo "  FAIL: override not applied"; exit 1; }

echo ""
echo "Test 4: cluster id is stable across restart"
id_before=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    cat /opt/containers/data/cluster.id | tr -d '[:space:]')
docker compose -f "$COMPOSE_FILE" restart "$SERVICE" >/dev/null
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180 >/dev/null
id_after=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    cat /opt/containers/data/cluster.id | tr -d '[:space:]')
[ -n "$id_before" ] && [ "$id_before" = "$id_after" ] \
    && echo "  PASS" || { echo "  FAIL: cluster id changed ($id_before -> $id_after)"; exit 1; }

echo ""
echo "Test 5: broker usable after restart"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null \
    && echo "  PASS" || { echo "  FAIL: broker unusable after restart"; exit 1; }

echo ""
echo "=== ALL EDGE-CASE TESTS PASSED ==="
