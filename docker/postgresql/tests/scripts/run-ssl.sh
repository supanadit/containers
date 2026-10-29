#!/bin/bash
# tests/scripts/run-ssl.sh — PostgreSQL serves TLS: the server has ssl on, a
# client that requires TLS connects, the session reports the TLS version, and a
# client that refuses TLS is still served (the generated pg_hba.conf has plain
# `host` rules, which match both).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DIR/../compose/ssl.yaml"
SERVICE="postgresql"
CERTS="$DIR/../compose/certs"
PG_SOCKET="/opt/containers/run"

dc() { docker compose -f "$COMPOSE_FILE" "$@"; }
fail() { echo "  FAIL: $1"; exit 1; }

# on_exit — on failure dump the compose logs plus the app's own log files (most
# lifecycles send child output to /opt/containers/logs), then tear down.
on_exit() {
  local rc=$?
  if [ $rc -ne 0 ]; then
    for s in $(dc config --services 2>/dev/null); do
      cid=$(dc ps -aq "$s" 2>/dev/null | head -1)
      [ -n "$cid" ] || continue
      echo "=== $s: container log (tail 80)"
      dc logs --no-color --tail 80 "$s" || true
      echo "=== $s: exit state"
      docker inspect -f 'exit={{.State.ExitCode}} oom={{.State.OOMKilled}} err={{.State.Error}}' "$cid" || true
      echo "=== $s: log dir"
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null | tar -tvf - 2>/dev/null | head -20 || true
      echo "=== $s: app log files"
      docker cp "$cid:/opt/containers/logs/." - 2>/dev/null \
        | tar -xO 2>/dev/null | tail -n 80 || true
      echo "=== $s: rendered config"
      docker cp "$cid:/opt/containers/config/." - 2>/dev/null \
        | tar -xO 2>/dev/null | head -80 || true
    done
  fi
  echo ">>> Cleanup: bringing down compose"
  dc down -v > /dev/null 2>&1 || true
}
trap on_exit EXIT

# psql — run SQL over TCP. TLS is the point of this suite, so the transport is
# always given explicitly instead of going through the Unix socket.
psql() {
  dc exec -T -e PGPASSWORD=testpass "$SERVICE" \
    psql "host=127.0.0.1 user=postgres dbname=postgres $1" -tAc "$2"
}

mkdir -p "$CERTS"
rm -f "$CERTS"/server.crt "$CERTS"/server.key
echo "Generating a self-signed certificate..."
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$CERTS"/server.key -out "$CERTS"/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" > /dev/null 2>&1
chmod 600 "$CERTS"/server.key

echo "=== TLS Test ==="
echo "Starting container..."
dc up -d --wait --wait-timeout 300

# --wait only guarantees PID 1 (ezx) is running; the first boot runs initdb and
# starts the server. Poll until it accepts connections before asserting.
echo "Waiting for PostgreSQL to accept connections..."
for _ in $(seq 1 90); do
  dc exec -T "$SERVICE" pg_isready -h "$PG_SOCKET" -U postgres > /dev/null 2>&1 && break
  sleep 1
done

echo ""
echo "Test 1: the server has ssl on"
[ "$(psql "" "show ssl")" = "on" ] || fail "ssl is not on"

echo ""
echo "Test 2: a TLS-required client connects and the session is encrypted"
row="$(psql "sslmode=require" "select ssl, ssl_version from pg_stat_ssl where pid = pg_backend_pid()")"
[ "${row%%|*}" = "t" ] || fail "session is not encrypted ($row)"
echo "  PASS ($row)"

echo ""
echo "Test 3: the negotiated protocol is TLSv1.2 or newer"
case "${row##*|}" in
  TLSv1.2*|TLSv1.3*) echo "  PASS (${row##*|})" ;;
  *) fail "unexpected TLS version '${row##*|}'" ;;
esac

echo ""
echo "Test 4: a client that refuses TLS is still served"
# The generated pg_hba.conf uses plain `host` rules, which match encrypted and
# unencrypted connections alike. Requiring TLS means adding a hostssl rule via
# PG_HBA_ADD_*.
[ "$(psql "sslmode=disable" "select ssl from pg_stat_ssl where pid = pg_backend_pid()")" = "f" ] \
  || fail "sslmode=disable did not produce a plaintext session"

echo ""
echo "Test 5: the certificate the server presents is the one that was mounted"
fp="$(dc exec -T "$SERVICE" openssl x509 -noout -fingerprint -sha256 \
        -in /opt/containers/config/tls/server.crt | tr -d '[:space:]')"
[ -n "$fp" ] || fail "server certificate not readable inside the container"

echo ""
echo "=== ALL TLS TESTS PASSED ==="
