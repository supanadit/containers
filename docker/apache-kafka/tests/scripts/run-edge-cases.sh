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
    for s in $(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null); do
      cid=$(docker compose -f "$COMPOSE_FILE" ps -aq "$s" 2>/dev/null | head -1)
      [ -n "$cid" ] || continue
      echo "=== $s: container log (tail 80)"
      docker compose -f "$COMPOSE_FILE" logs --no-color --tail 80 "$s" || true
      echo "=== $s: exit state"
      docker inspect -f 'exit={{.State.ExitCode}} oom={{.State.OOMKilled}} err={{.State.Error}}' "$cid" || true
      echo "=== $s: log dir"
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null | tar -tvf - 2>/dev/null | head -20 || true
      echo "=== $s: app log files"
      # Most lifecycles write child output to files under /opt/containers, and a
      # crash leaves the container exited where `exec` cannot reach it: docker cp
      # reads them out of the stopped container.
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null \
        | tar -xO 2>/dev/null | tail -n 80 || true
      echo "=== $s: rendered config"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null \
        | tar -xO 2>/dev/null | head -80 || true
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
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
# bootstrap writes /opt/containers/data/cluster.id while starting; this compose
# file has no healthcheck, so wait for the file instead of racing the boot.
wait_cluster_id() {
  local deadline=$((SECONDS + 180))
  until docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" test -s /opt/containers/data/cluster.id 2>/dev/null; do
    if [ $SECONDS -ge $deadline ]; then echo "  FAIL: cluster.id never written"; return 1; fi
    sleep 2
  done
}

echo "Test 4: cluster id is stable across restart"
wait_cluster_id || exit 1
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
