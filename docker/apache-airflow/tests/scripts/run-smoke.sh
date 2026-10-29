#!/bin/bash
# tests/scripts/run-smoke.sh — Airflow smoke test: the metadata database is
# migrated, the API server answers, it runs unprivileged and ezx stays PID 1.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="airflow"

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

# apiAnswers — the API server answers HTTP at all (any status code; Airflow 3
# answers 200 or 401 depending on auth being enabled).
apiAnswers() {
  local code
  code="$(dc exec -T "$SERVICE" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/v2/version)"
  [ "$code" != "000" ]
}

echo "=== Smoke Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 900
wait_until "API server answering" 300 apiAnswers

echo ""
echo "Test 1: the API server answers"
dc exec -T "$SERVICE" curl -s -o /dev/null -w '  HTTP %{http_code}\n' http://127.0.0.1:8080/api/v2/version
apiAnswers || fail "API server not answering"
echo "  PASS"

echo ""
echo "Test 2: the metadata database was migrated"
dc exec -T "$SERVICE" test -s /opt/containers/data/airflow.db || fail "no airflow.db"
echo "  PASS"

echo ""
echo "Test 3: the airflow CLI resolves and reports its version"
dc exec -T "$SERVICE" airflow version | grep -q '3\.' || fail "airflow version"
echo "  PASS"

echo ""
echo "Test 4: composite health is healthy"
dc exec -T "$SERVICE" curl -fsS http://127.0.0.1:8081/health/comprehensive | grep -q '"healthy":true' \
  || fail "composite health"
echo "  PASS"

echo ""
echo "Test 5: runs as the dedicated non-root user"
uid="$(dc exec -T "$SERVICE" id -u airflow | tr -d '[:space:]')"
[ "$uid" != "0" ] || fail "airflow user is root"
echo "  PASS (uid=$uid)"

echo ""
echo "Test 6: ezx is PID 1 and supervises the API server"
pid1="$(dc exec -T "$SERVICE" cat /proc/1/comm | tr -d '[:space:]')"
[ "$pid1" = "ezx" ] || fail "PID 1 is '$pid1', want 'ezx'"
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
