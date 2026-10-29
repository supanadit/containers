#!/bin/bash
# tests/scripts/run-smoke.sh — Loki smoke test: the server reports ready, a
# pushed log line is queryable back, it runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="loki"
TS="$(date +%s)000000000"

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

# on_exit — on failure dump the compose logs plus the app's own log files (most
# lifecycles send child output to /opt/containers/logs), then tear down.
on_exit() {
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo ">>> Failure: container logs"
    dc logs --no-color --tail 120 || true
    for s in $(dc config --services 2>/dev/null); do
      cid=$(dc ps -aq "$s" 2>/dev/null | head -1)
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
  dc down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

ready() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:3100/ready; }

pushLine() {
  dc exec -T "$SERVICE" curl -fsS -X POST \
    -H 'Content-Type: application/json' \
    --data "{\"streams\":[{\"stream\":{\"job\":\"smoke\"},\"values\":[[\"$TS\",\"hello-from-smoke\"]]}]}" \
    http://127.0.0.1:3100/loki/api/v1/push
}

queryLine() {
  dc exec -T "$SERVICE" curl -fsS \
    'http://127.0.0.1:3100/loki/api/v1/query_range?query=%7Bjob%3D%22smoke%22%7D&limit=10' \
    | grep -q hello-from-smoke
}

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "Loki /ready" 60 ready

echo ""
echo "Test 1: Loki reports itself ready"
ready | grep -q 'ready' || fail "/ready"
echo "  PASS"

echo ""
echo "Test 2: a pushed log line is queryable back"
pushLine > /dev/null || fail "push rejected"
wait_until "pushed line queryable" 30 queryLine
echo "  PASS"

echo ""
echo "Test 3: loki.yaml was generated into the config volume"
dc exec -T "$SERVICE" test -s /opt/containers/config/loki.yaml || fail "no loki.yaml"
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u loki | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "loki user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises Loki"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
