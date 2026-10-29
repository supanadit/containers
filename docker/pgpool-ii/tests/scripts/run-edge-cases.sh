#!/bin/bash
# tests/scripts/run-edge-cases.sh — PgPool-II validation edge cases:
#   * PGPOOL_BACKENDS is required
#   * watchdog requires a hostname and a delegate IP
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/edge-cases.yaml"

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
  printf '%s' "$out" | grep -c "$pattern" > /dev/null \
    || { echo "  FAIL: $label (missing '$pattern')"; echo "$out" | tail -20; exit 1; }
  echo "  PASS ($label, exit $code)"
}

echo ""
echo "Test 1: PGPOOL_BACKENDS is required"
expect_failure pgpool-no-backends "PGPOOL_BACKENDS environment variable is required" "missing backends"

echo ""
echo "Test 2: watchdog without a hostname/delegate IP is rejected"
expect_failure pgpool-watchdog-missing "PGPOOL_WD_HOSTNAME is required" "watchdog missing hostname"

echo ""
echo "=== ALL EDGE CASE TESTS PASSED ==="
