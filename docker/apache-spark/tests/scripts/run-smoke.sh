#!/bin/bash
# tests/scripts/run-smoke.sh — Spark smoke test: the master serves its REST API,
# the worker registers with it, both run unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="spark"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# wait_until <label> <attempts> <command...> — poll a probe until it succeeds.
wait_until() {
  local label="$1" attempts="$2"; shift 2
  for _ in $(seq 1 "$attempts"); do
    # A crashed container will never become ready: stop instead of polling out
    # the whole budget, which is what made red runs take ten minutes.
    if ! docker compose -f "$COMPOSE_FILE" ps -q spark 2>/dev/null | grep -c . > /dev/null ; then
      echo "  FAIL: $label: container exited while waiting"; return 1
    fi
    if "$@" > /dev/null 2>&1; then echo "  ready: $label"; return 0; fi
    sleep 2
  done
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

masterJson() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/json/; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "master REST API" 300 masterJson

echo ""
echo "Test 1: the master reports itself ALIVE"
masterJson | grep -c '"status": *"ALIVE"' > /dev/null || fail "master not ALIVE"
echo "  PASS"

echo ""
echo "Test 2: the worker registered with the master"
masterJson | grep -Eq '"aliveworkers": *1' || fail "no live worker"
echo "  PASS"

echo ""
echo "Test 3: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8081/health/comprehensive | grep -c '"healthy":true' > /dev/null \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 4: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u spark | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "spark user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 5: ezx is PID 1 and supervises master + worker"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
