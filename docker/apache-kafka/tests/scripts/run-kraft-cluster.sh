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

echo "=== KRaft Cluster Test ==="
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 240

echo ""
echo "Test 1: all three brokers registered"
docker compose -f "$COMPOSE_FILE" exec -T kafka-1 \
    kafka-metadata-quorum.sh --bootstrap-server localhost:9093 describe --status \
    | grep -q "CurrentVoters" && echo "  PASS" || { echo "  FAIL: no quorum status"; exit 1; }

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
