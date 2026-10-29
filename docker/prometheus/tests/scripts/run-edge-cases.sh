#!/bin/bash
# tests/scripts/run-edge-cases.sh — Prometheus edge cases:
#   * an explicitly set PROMETHEUS_CONFIG_FILE is honoured
#   * a missing explicit config file fails fast (no silent default fallback)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/edge-cases.yaml"

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

echo "=== Edge Cases Test ==="

# expect_failure <service> <pattern> <label> — start a service that is expected
# to exit non-zero, then assert its exit code and a message in its logs.
# `docker compose up` returns 0 even when the container exits non-zero, so the
# container's own exit code has to be read explicitly.
expect_failure() {
  local svc="$1" pattern="$2" label="$3"
  docker compose -f "$COMPOSE_FILE" up -d "$svc" >/dev/null 2>&1 || true
  local cid="" state="" code=""
  for _ in $(seq 1 30); do
    cid="$(docker compose -f "$COMPOSE_FILE" ps -aq "$svc")"
    [ -n "$cid" ] || { sleep 1; continue; }
    state="$(docker inspect -f '{{.State.Status}}' "$cid")"
    if [ "$state" = "exited" ]; then
      code="$(docker inspect -f '{{.State.ExitCode}}' "$cid")"
      break
    fi
    sleep 1
  done
  [ -n "$code" ] || { echo "  FAIL: $label (container never exited)"; exit 1; }
  [ "$code" != "0" ] || { echo "  FAIL: $label (exited 0, expected failure)"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
  local out; out="$(docker logs "$cid" 2>&1)"
  printf '%s' "$out" | grep -q "$pattern" \
    || { echo "  FAIL: $label (missing '$pattern')"; echo "$out" | tail -20; exit 1; }
  echo "  PASS ($label, exit $code)"
}

echo ""
echo "Test 1: explicit config file is used"
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180 prometheus-custom
docker compose -f "$COMPOSE_FILE" exec -T prometheus-custom \
  curl -fsS http://127.0.0.1:9091/api/v1/status/config | grep -q 'localhost:9091' \
  || { echo "  FAIL: custom config was not loaded"; exit 1; }
echo "  PASS"

echo ""
echo "Test 2: a missing explicit config file fails fast"
expect_failure prometheus-missing "configuration file not found" "missing config"

echo ""
echo "=== ALL EDGE CASE TESTS PASSED ==="
