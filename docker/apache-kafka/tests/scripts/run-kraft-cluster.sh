#!/bin/bash
# tests/scripts/run-kraft-cluster.sh — 3-node combined KRaft cluster test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/kraft-cluster.yaml"

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

echo "=== KRaft Cluster Test ==="
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 240

# The compose healthcheck only proves the JVM exists (pgrep), so `--wait`
# returns while the node is still "waiting to be unfenced". Poll the quorum
# through the *broker* listener: kafka-metadata-quorum.sh is an admin client,
# and pointed at the controller listener (9093) it answers
# UnsupportedVersionException ("The node does not support METADATA") forever.
wait_quorum() {
  local deadline=$((SECONDS + 180))
  until docker compose -f "$COMPOSE_FILE" exec -T kafka-1 \
        kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status 2>/dev/null \
        | grep -q "CurrentVoters"; do
    if [ $SECONDS -ge $deadline ]; then
      echo "  FAIL: quorum never formed"
      return 1
    fi
    sleep 5
  done
}

echo ""
echo "Test 1: all three brokers registered"
wait_quorum || exit 1
echo "  PASS"

echo ""
echo "Test 2: create a replication-factor-3 topic"
docker compose -f "$COMPOSE_FILE" exec -T kafka-1 \
    kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic rf3-topic --partitions 3 --replication-factor 3
echo "  PASS"

echo ""
echo "Test 3: topic is fully replicated (3 replicas)"
docker compose -f "$COMPOSE_FILE" exec -T kafka-1 \
    kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic rf3-topic \
    | grep -q "ReplicationFactor: 3" && echo "  PASS" || { echo "  FAIL: replication factor wrong"; exit 1; }

echo ""
echo "Test 4: produce/consume round-trip"
docker compose -f "$COMPOSE_FILE" exec -T kafka-1 bash -c \
    'printf "hello\n" | kafka-console-producer.sh --bootstrap-server localhost:9092 --topic rf3-topic'
docker compose -f "$COMPOSE_FILE" exec -T kafka-1 \
    kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic rf3-topic --from-beginning --max-messages 1 --timeout-ms 30000 \
    | grep -q "hello" && echo "  PASS" || { echo "  FAIL: round-trip failed"; exit 1; }

echo ""
echo "=== ALL KRAFT CLUSTER TESTS PASSED ==="
