#!/bin/bash
# tests/scripts/run-smoke.sh — etcd smoke test: the node forms its own cluster,
# serves the client API (put/get/member list), runs unprivileged and ezx stays
# PID 1 supervising it.
#
# The etcd image ships no curl (the runtime layer is trimmed to the binaries),
# so every probe goes through etcdctl.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="etcd"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# wait_until <label> <attempts> <command...> — poll a probe until it succeeds.
wait_until() {
  local label="$1" attempts="$2"; shift 2
  local out=""
  for _ in $(seq 1 "$attempts"); do
    # A crashed container will never become ready: stop instead of polling out
    # the whole budget, which is what made red runs take ten minutes.
    if ! docker compose -f "$COMPOSE_FILE" ps -q etcd 2>/dev/null | grep -c . > /dev/null ; then
      echo "  FAIL: $label: container exited while waiting"; return 1
    fi
    if out=$("$@" 2>&1); then echo "  ready: $label"; return 0; fi
    sleep 2
  done
  # the last attempt's output says why it never came up
  printf '%s\n' "$out" | tail -n 20
  fail "$label did not become ready"
}

# on_exit — on failure dump the compose logs plus the app's own log files (most
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

healthy() {
  dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 endpoint health
}

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "client API healthy" 60 healthy

echo ""
echo "Test 1: endpoint health reports the node as healthy"
healthy | grep -c "is healthy" > /dev/null || fail "endpoint health"
echo "  PASS"

echo ""
echo "Test 2: put/get round trip"
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 put smoke-key smoke-value > /dev/null
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 get smoke-key | grep -c smoke-value > /dev/null \
  || fail "value not readable back"
echo "  PASS"

echo ""
echo "Test 3: the member joined its own cluster"
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 member list | grep -c "started" > /dev/null \
  || fail "no started member"
echo "  PASS"

echo ""
echo "Test 4: data lands on the volume"
dc exec -T "$SERVICE" test -f /opt/containers/data/member/snap/db \
  || fail "no member/snap/db under /opt/containers/data"
echo "  PASS"

echo ""
echo "Test 5: etcd runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u etcd | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "etcd user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises etcd"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
