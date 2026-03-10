#!/bin/bash
# healthcheck.sh - Health check for FreeRADIUS container

set -euo pipefail

RADIUS_HOST="${RADIUS_HOST:-127.0.0.1}"
RADIUS_AUTH_PORT="${RADIUS_AUTH_PORT:-1812}"
RADIUS_STATUS_PORT="${RADIUS_STATUS_PORT:-}"
HEALTH_CHECK_SECRET="${HEALTH_CHECK_SECRET:-secret}"
MAX_ATTEMPTS="${HEALTH_CHECK_MAX_ATTEMPTS:-3}"
ATTEMPT_INTERVAL="${HEALTH_CHECK_ATTEMPT_INTERVAL:-1}"

check_radius_process() {
    if pgrep -x radiusd &>/dev/null; then
        return 0
    fi
    return 1
}

check_radius_port() {
    local host="$1"
    local port="$2"
    
    if timeout 2 bash -c "echo '' > /dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    fi
    return 1
}

check_radius_status() {
    local status_port="${RADIUS_STATUS_PORT:-}"
    
    if [[ -z "$status_port" ]]; then
        return 1
    fi
    
    local secret="$HEALTH_CHECK_SECRET"
    
    local response
    response=$(echo "Message-Authenticator = 0x00, FreeRADIUS-Statistics-Type = 1" | \
        radclient -x "$RADIUS_HOST:$status_port" status "$secret" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q "FreeRADIUS-Statistics-Type"; then
        return 0
    fi
    
    return 1
}

main() {
    if ! check_radius_process; then
        echo "FreeRADIUS process not running"
        exit 1
    fi
    
    if ! check_radius_port "$RADIUS_HOST" "$RADIUS_AUTH_PORT"; then
        echo "FreeRADIUS auth port $RADIUS_AUTH_PORT not responding"
        exit 1
    fi
    
    if [[ -n "$RADIUS_STATUS_PORT" ]]; then
        if ! check_radius_status; then
            echo "FreeRADIUS status port not responding"
            exit 1
        fi
    fi
    
    echo "FreeRADIUS is healthy"
    exit 0
}

main "$@"
