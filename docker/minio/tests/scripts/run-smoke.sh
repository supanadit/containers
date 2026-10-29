#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal MinIO smoke test.
#
# MinIO's runtime image is slim and intentionally ships no client, so the HTTP
# surfaces are exercised from the host over the published ports. The S3 API is
# checked by its unauthenticated behaviour (401/403) rather than by signing a
# request: that proves the server is enforcing auth without a hand-rolled SigV4.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="minio"
ENDPOINT="http://127.0.0.1:19000"
CONSOLE="http://127.0.0.1:19001"

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

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

# --wait only guarantees PID 1 (ezx) is running; poll until MinIO answers.
for _ in $(seq 1 60); do
  curl -fsS "${ENDPOINT}/minio/health/ready" > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: MinIO readiness probe"
curl -fsS "${ENDPOINT}/minio/health/ready" > /dev/null
echo "  PASS"

echo ""
echo "Test 2: MinIO liveness probe"
curl -fsS "${ENDPOINT}/minio/health/live" > /dev/null
echo "  PASS"

echo ""
echo "Test 3: the S3 API enforces authentication"
code="$(curl -s -o /dev/null -w '%{http_code}' "${ENDPOINT}/")"
case "$code" in
  401|403) echo "  PASS (unauthenticated ListBuckets -> $code)" ;;
  *) echo "  FAIL: expected 401/403 from an unauthenticated S3 request, got $code"; exit 1 ;;
esac

echo ""
echo "Test 4: the console is served"
code="$(curl -s --retry 20 --retry-delay 2 --retry-all-errors -o /dev/null -w '%{http_code}' "${CONSOLE}/")"
[ "$code" = "200" ] || { echo "  FAIL: console returned $code"; exit 1; }
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" id -u minio | tr -d '[:space:]')"
[ "$uid" != "0" ] || { echo "  FAIL: minio user is root"; exit 1; }
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises MinIO"
pid1="$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || { echo "  FAIL: PID 1 is '$pid1', want 'ezx'"; exit 1; }
echo "  PASS"
# pgrep/ps are not installed in MinIO's slim runtime, so scan /proc directly.
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" sh -c '
  for p in /proc/[0-9]*; do
    [ "$(cat "$p/comm" 2>/dev/null)" = "minio" ] && exit 0
  done
  exit 1
' || { echo "  FAIL: no minio process"; exit 1; }
echo "  PASS (minio supervised)"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
