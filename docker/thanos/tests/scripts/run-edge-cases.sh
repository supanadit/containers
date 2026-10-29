#!/bin/bash
# tests/scripts/run-edge-cases.sh — Thanos edge cases:
#   * the S3 shorthand renders a 0600 objstore file, keeping the secret out of
#     the process arguments
#   * an incomplete S3 shorthand is rejected
#   * an unknown component is rejected
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
      echo "=== $s: exit state"
      docker inspect -f 'exit={{.State.ExitCode}} oom={{.State.OOMKilled}} err={{.State.Error}}' "$cid" || true
      echo "=== $s: log dir"
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null | tar -tvf - 2>/dev/null | head -20 || true
      echo "=== $s: app log files"
      # Most lifecycles write child output to files under /opt/containers, and a
      # crash leaves the container exited where `exec` cannot reach it: docker cp
      # reads them out of the stopped container.
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null \
        | tar -xO 2>/dev/null | tail -n 80 || true
      echo "=== $s: rendered config"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null \
        | tar -xO 2>/dev/null | head -80 || true
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
echo "Test 1: S3 shorthand renders a 0600 objstore file"
# The store will not become ready (no S3 endpoint), so start it detached and
# inspect the file ezx rendered with `docker exec` — never a bind mount, which
# the bootstrap's recursive chown would re-own on the host.
docker compose -f "$COMPOSE_FILE" up -d thanos-store >/dev/null
for _ in $(seq 1 30); do
  docker compose -f "$COMPOSE_FILE" exec -T thanos-store test -f /opt/containers/config/thanos-objstore.yaml 2>/dev/null && break
  sleep 1
done
docker compose -f "$COMPOSE_FILE" exec -T thanos-store test -f /opt/containers/config/thanos-objstore.yaml \
  || { echo "  FAIL: objstore file was not written"; exit 1; }
objstore="$(docker compose -f "$COMPOSE_FILE" exec -T thanos-store cat /opt/containers/config/thanos-objstore.yaml)"
printf '%s' "$objstore" | grep -c "access_key: superadmin" > /dev/null || { echo "  FAIL: access_key missing"; echo "$objstore"; exit 1; }
printf '%s' "$objstore" | grep -c "secret_key: supersecretpassword" > /dev/null || { echo "  FAIL: secret_key missing"; exit 1; }
perms="$(docker compose -f "$COMPOSE_FILE" exec -T thanos-store stat -c '%a' /opt/containers/config/thanos-objstore.yaml)"
[ "$perms" = "600" ] || { echo "  FAIL: objstore file is $perms, want 600"; exit 1; }
echo "  PASS (mode 600)"

echo ""
echo "Test 2: the secret never appears in the process arguments"
# Scan each process's argv, skipping self/thread-self: the grep command line
# itself contains the literal secret and would otherwise match.
leaked="$(docker compose -f "$COMPOSE_FILE" exec -T thanos-store sh -c '
  for p in /proc/[0-9]*; do
    pid="${p#/proc/}"
    [ "$pid" = "$$" ] && continue
    if tr "\0" "\n" < "$p/cmdline" 2>/dev/null | grep -aq supersecretpassword; then
      echo "$pid"
    fi
  done
')"
[ -z "$leaked" ] || { echo "  FAIL: secret leaked into argv of: $leaked"; exit 1; }
echo "  PASS"

echo ""
echo "Test 3: an incomplete S3 shorthand is rejected"
expect_failure thanos-bad-s3 "Incomplete S3 configuration" "incomplete S3"

echo ""
echo "Test 4: an unknown component is rejected"
expect_failure thanos-bad-component "Unknown component" "unknown component"

echo ""
echo "=== ALL EDGE CASE TESTS PASSED ==="
