#!/bin/bash
# tests/scripts/run-sasl.sh — SASL_PLAINTEXT (PLAIN) end-to-end test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/sasl.yaml"
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
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

echo "=== SASL Test ==="
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

echo ""
echo "Test 1: authenticated client can list topics"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'cat > /tmp/client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="admin" password="admin-secret";
EOF'
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --command-config /tmp/client.properties --list
echo "  PASS"

echo ""
echo "Test 2: a second PLAIN user can authenticate"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'cat > /tmp/client2.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="client" password="client-secret";
EOF'
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --command-config /tmp/client2.properties --list
echo "  PASS"

echo ""
echo "=== ALL SASL TESTS PASSED ==="
