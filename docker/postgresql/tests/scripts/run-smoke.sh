#!/bin/bash
# tests/scripts/run-smoke.sh — Minimal PostgreSQL smoke test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/smoke.yaml"
SERVICE="postgresql"

trap 'echo ">>> Cleanup: bringing down compose"; docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true' EXIT

echo "=== Smoke Test ==="
echo "Starting container..."
docker compose -f "$COMPOSE_FILE" up -d --wait --wait-timeout 180

echo ""
echo "Test 1: pg_isready"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pg_isready -U postgres
echo "  PASS"

echo ""
echo "Test 2: SELECT 1"
result=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -U postgres -tA -c "SELECT 1;" | tr -d '[:space:]')
[ "$result" = "1" ] && echo "  PASS" || { echo "  FAIL: expected '1', got '$result'"; exit 1; }

echo ""
echo "Test 3: PostgreSQL version"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -U postgres -tA -c "SELECT version();" | grep -q "PostgreSQL" || { echo "  FAIL: version check"; exit 1; }
echo "  PASS"

echo ""
echo "Test 4: Server process running"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" pgrep -f "postgres" > /dev/null || { echo "  FAIL: no postgres process"; exit 1; }
echo "  PASS"

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
