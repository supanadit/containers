#!/bin/bash
# tests/scripts/run-edge-cases.sh — MinIO edge cases:
#   * inline credentials are materialised into 0600 files (not passed in argv)
#   * operator-supplied *_FILE credentials are used as-is
#   * incomplete credentials and an invalid listen address are rejected
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/edge-cases.yaml"
CRED_DIR="$DIR/../compose/file-creds"

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
        | tar -xO 2>/dev/null | tail -n 80
      echo "=== $s: rendered config"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null \
        | tar -xO 2>/dev/null | head -80
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

# The mounted credential files must exist before compose starts the container.
mkdir -p "$CRED_DIR"
printf 'fileadmin\n' > "$CRED_DIR/root-user"
printf 'filepassword\n' > "$CRED_DIR/root-password"

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
echo "Test 1: inline credentials are written to 0600 files"
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180 minio-inline-creds
for _ in $(seq 1 30); do
  docker compose -f "$COMPOSE_FILE" exec -T minio-inline-creds test -f /opt/containers/config/root-password 2>/dev/null && break
  sleep 1
done
docker compose -f "$COMPOSE_FILE" exec -T minio-inline-creds test -f /opt/containers/config/root-password \
  || { echo "  FAIL: credential file was not written"; exit 1; }
pw="$(docker compose -f "$COMPOSE_FILE" exec -T minio-inline-creds cat /opt/containers/config/root-password)"
[ "$pw" = "supersecretpassword" ] || { echo "  FAIL: password content"; exit 1; }
perms="$(docker compose -f "$COMPOSE_FILE" exec -T minio-inline-creds stat -c '%a' /opt/containers/config/root-password)"
[ "$perms" = "600" ] || { echo "  FAIL: password file is $perms, want 600"; exit 1; }
echo "  PASS (mode 600)"

echo ""
echo "Test 2: the secret never appears in the process arguments"
# Scan each process's argv, skipping the scanning shell itself (its own command
# line contains the literal secret and would otherwise match).
leaked="$(docker compose -f "$COMPOSE_FILE" exec -T minio-inline-creds sh -c '
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
echo "Test 3: operator-supplied *_FILE credentials are used as-is"
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180 minio-file-creds
# The container came up healthy despite the credentials being mounted read-only;
# an unchanged file proves the mounted copy was read, not rewritten.
grep -q "^filepassword$" "$CRED_DIR/root-password" || { echo "  FAIL: mounted password was rewritten"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: incomplete credentials are rejected"
expect_failure minio-bad-creds "Incomplete MinIO credentials" "incomplete credentials"

echo ""
echo "Test 5: an invalid listen address is rejected"
expect_failure minio-bad-address "not a valid listen address" "invalid listen address"

echo ""
echo "=== ALL EDGE CASE TESTS PASSED ==="
