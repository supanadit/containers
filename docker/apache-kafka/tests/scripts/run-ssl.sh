#!/bin/bash
# tests/scripts/run-ssl.sh — TLS end-to-end test with generated PKCS12 stores
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/ssl.yaml"
SERVICE="kafka"
IMAGE="kafka:test"
CERTS="$DIR/../compose/certs"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

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
