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
