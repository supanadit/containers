#!/bin/bash
# tests/scripts/run-smoke.sh — minimal Kafka KRaft smoke test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="kafka"

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

echo ""
echo "Test 1: kafka-topics.sh --list"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --list
echo "  PASS"

echo ""
echo "Test 2: create + describe a topic"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic smoke-topic --partitions 1 --replication-factor 1
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic smoke-topic)
echo "$result" | grep -q "smoke-topic" && echo "  PASS" || { echo "  FAIL: topic not described"; exit 1; }

echo ""
echo "Test 3: KRaft cluster id file exists"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    test -s /opt/containers/data/cluster.id || { echo "  FAIL: cluster.id missing"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
    || { echo "  FAIL: health not healthy"; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: broker JVM is running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    pgrep -f "kafka.Kafka" > /dev/null || { echo "  FAIL: no kafka java process"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
