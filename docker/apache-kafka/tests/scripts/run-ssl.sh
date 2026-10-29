#!/bin/bash
# tests/scripts/run-ssl.sh — TLS end-to-end test with generated PKCS12 stores
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/ssl.yaml"
SERVICE="kafka"
IMAGE="kafka:test"
CERTS="$DIR/../compose/certs"

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

echo "=== SSL Test ==="
mkdir -p "$CERTS"
rm -f "$CERTS"/kafka.keystore.p12 "$CERTS"/kafka.truststore.p12 "$CERTS"/kafka.crt

echo "Generating certificates with keytool from the image..."
docker run --rm -v "$CERTS":/certs --entrypoint keytool "$IMAGE" \
    -genkeypair -alias kafka -keyalg RSA -keysize 2048 -dname "CN=localhost" \
    -ext "SAN=dns:localhost,ip:127.0.0.1" \
    -keystore /certs/kafka.keystore.p12 -storepass keystore-password \
    -keypass keystore-password -storetype PKCS12
docker run --rm -v "$CERTS":/certs --entrypoint keytool "$IMAGE" \
    -exportcert -alias kafka -file /certs/kafka.crt \
    -keystore /certs/kafka.keystore.p12 -storepass keystore-password
docker run --rm -v "$CERTS":/certs --entrypoint keytool "$IMAGE" \
    -importcert -alias kafka -file /certs/kafka.crt \
    -keystore /certs/kafka.truststore.p12 -storepass truststore-password \
    -storetype PKCS12 -noprompt

echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

echo ""
echo "Test 1: TLS client can list topics"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" bash -c 'cat > /tmp/client.properties <<EOF
security.protocol=SSL
ssl.truststore.location=/opt/containers/config/kafka.truststore.p12
ssl.truststore.password=truststore-password
ssl.endpoint.identification.algorithm=
EOF'
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    kafka-topics.sh --bootstrap-server localhost:9092 --command-config /tmp/client.properties --list
echo "  PASS"

echo ""
echo "Test 2: configured keystore is present and used"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    grep -q '^ssl.keystore.location=/opt/containers/config/kafka.keystore.p12$' \
    /opt/containers/config/server.properties \
    && echo "  PASS" || { echo "  FAIL: ssl.keystore.location missing"; exit 1; }

echo ""
echo "=== ALL SSL TESTS PASSED ==="
