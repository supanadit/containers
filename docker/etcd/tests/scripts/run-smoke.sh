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
  for _ in $(seq 1 "$attempts"); do
    if "$@" > /dev/null 2>&1; then echo "  ready: $label"; return 0; fi
    sleep 2
  done
  fail "$label did not become ready"
}

trap 'rc=$?; if [ $rc -ne 0 ]; then echo ">>> Failure: container logs"; dc logs --no-color --tail 120 || true; fi; echo ">>> Cleanup: bringing down compose"; dc down -v > /dev/null 2>&1 || true' EXIT

healthy() {
  dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 endpoint health
}

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "client API healthy" 60 healthy

echo ""
echo "Test 1: endpoint health reports the node as healthy"
healthy | grep -q "is healthy" || fail "endpoint health"
echo "  PASS"

echo ""
echo "Test 2: put/get round trip"
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 put smoke-key smoke-value > /dev/null
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 get smoke-key | grep -q smoke-value \
  || fail "value not readable back"
echo "  PASS"

echo ""
echo "Test 3: the member joined its own cluster"
dc exec -T "$SERVICE" etcdctl --endpoints=http://127.0.0.1:2379 member list | grep -q "started" \
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
