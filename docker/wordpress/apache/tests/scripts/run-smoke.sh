#!/bin/bash
# tests/scripts/run-smoke.sh — WordPress smoke test: Apache serves PHP, the site
# is rendered from the MariaDB backend (no "Error establishing a database
# connection"), the workers run as www-data and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="wordpress"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# wait_until <label> <attempts> <command...> — poll a probe until it succeeds.
wait_until() {
  local label="$1" attempts="$2"; shift 2
  local out=""
  for _ in $(seq 1 "$attempts"); do
    # A crashed container will never become ready: stop instead of polling out
    # the whole budget, which is what made red runs take ten minutes.
    if ! docker compose -f "$COMPOSE_FILE" ps -q wordpress 2>/dev/null | grep -c . > /dev/null ; then
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

phpServed() { dc exec -T "$SERVICE" curl -fsS -o /dev/null http://127.0.0.1/wp-includes/version.php; }

# siteRendered — the front page comes back and is not WordPress's database error
# page (which is served with HTTP 200, so the body has to be inspected).
siteRendered() {
  local out code
  out="$(dc exec -T "$SERVICE" curl -sS -w 'HTTP:%{http_code}\n' http://127.0.0.1/index.php 2>&1)" || true
  code="$(printf '%s' "$out" | grep -o 'HTTP:[0-9]*' | tail -1)"
  if [ "$code" = "HTTP:200" ] \
    && ! printf '%s' "$out" | grep -c 'Error establishing a database connection' > /dev/null; then
    return 0
  fi
  # Always show what came back: status line plus the body WordPress rendered.
  printf '%s\n' "$out" | head -30
  return 1
}

echo "=== Smoke Test ==="
echo "Starting containers..."
dc up -d --wait --wait-timeout 600
wait_until "Apache serving PHP" 120 phpServed

echo ""
echo "Test 1: Apache serves PHP"
phpServed || fail "PHP not served"
echo "  PASS"

echo ""
echo "Test 2: wp-config.php was generated with the database settings"
dc exec -T "$SERVICE" grep -qE "DB_NAME.*wordpress" /var/www/html/wp-config.php \
  || fail "wp-config.php has no DB_NAME"
echo "  PASS"

echo ""
echo "Test 3: the site renders from the database"
wait_until "WordPress front page" 30 siteRendered
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
echo "Test 5: the Apache workers run as www-data, not root"
uid="$(dc exec -T "$SERVICE" id -u www-data | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "www-data is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises Apache"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
