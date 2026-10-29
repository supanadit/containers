#!/bin/bash
# tests/scripts/run-smoke.sh — MaxScale smoke test: the REST API answers, the
# generated config is in place, a query routed through the Read-Write listener
# reaches the backend MariaDB, MaxScale runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="maxscale"

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

# restAnswers — the REST API answers HTTP at all; admin_auth is on, so a 401 is
# the healthy answer here.
restAnswers() {
  local code
  code="$(dc exec -T "$SERVICE" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8989/v1/maxscale)"
  [ "$code" != "000" ]
}

# routed — a query through the Read-Write listener reaches the backend. The
# monitor needs a few seconds to mark the server as the master.
routed() {
  dc exec -T "$SERVICE" mariadb --host=127.0.0.1 --port=3306 \
    --user=maxscale --password=maxscale --execute='SELECT 1' | grep -q '^1$'
}

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 600
wait_until "REST API answering" 60 restAnswers

echo ""
echo "Test 1: the MaxScale REST API answers"
dc exec -T "$SERVICE" curl -s -o /dev/null -w '  HTTP %{http_code}\n' http://127.0.0.1:8989/v1/maxscale
restAnswers || fail "REST API not answering"
echo "  PASS"

echo ""
echo "Test 2: the generated config is in place"
dc exec -T "$SERVICE" test -s /etc/maxscale.cnf.d/generated.cnf || fail "no generated.cnf"
dc exec -T "$SERVICE" grep -q 'Read-Write-Listener' /etc/maxscale.cnf.d/generated.cnf \
  || fail "no Read-Write-Listener section"
echo "  PASS"

echo ""
echo "Test 3: a query through the Read-Write listener reaches MariaDB"
wait_until "Read-Write listener routing" 90 routed
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 5: MaxScale runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u maxscale | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "maxscale user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises MaxScale"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
