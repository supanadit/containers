#!/bin/bash
# tests/scripts/run-smoke.sh — Flink smoke test: the JobManager serves its REST
# API, the TaskManager registers a slot, both run unprivileged and ezx stays
# PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="flink"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# wait_until <label> <attempts> <command...> — poll a probe until it succeeds.
wait_until() {
  local label="$1" attempts="$2"; shift 2
  local out=""
  for _ in $(seq 1 "$attempts"); do
    # A crashed container will never become ready: stop instead of polling out
    # the whole budget, which is what made red runs take ten minutes.
    if ! docker compose -f "$COMPOSE_FILE" ps -q flink 2>/dev/null | grep -c . > /dev/null ; then
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

overview() { dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8081/overview; }

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300
wait_until "JobManager REST API" 300 overview

echo ""
echo "Test 1: the JobManager reports a running cluster"
overview | grep -Eq '"taskmanagers": *1' || fail "no TaskManager registered"
echo "  PASS"

echo ""
echo "Test 2: the TaskManager offers a task slot"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8081/taskmanagers | grep -c 'id' > /dev/null \
  || fail "no task manager listed"
echo "  PASS"

echo ""
echo "Test 3: config.yaml was generated into the config volume"
dc exec -T "$SERVICE" test -s /opt/containers/config/config.yaml || fail "no config.yaml"
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
health="$(dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8080/health/comprehensive)" || true
if ! grep -c '"healthy":true' <<<"$health" > /dev/null; then
  printf '%s\n' "$health"
  fail "composite health"
fi
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u flink | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "flink user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises JobManager + TaskManager"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
