#!/bin/bash
# healthcheck.sh - Health check for FreeRADIUS container

set -euo pipefail

RADIUS_AUTH_PORT="${RADIUS_AUTH_PORT:-1812}"

check_radius_process() {
    if ps aux | grep -v grep | grep -q radiusd; then
        return 0
    fi
    return 1
}

check_radius_port() {
    local port="$1"
    
    if timeout 2 bash -c "echo >/dev/udp/127.0.0.1/$port" 2>/dev/null; then
        return 0
    fi
    return 1
}

main() {
    if ! check_radius_process; then
        echo "FreeRADIUS process not running"
        exit 1
    fi
    
    if ! check_radius_port "$RADIUS_AUTH_PORT"; then
        echo "FreeRADIUS auth port $RADIUS_AUTH_PORT not responding"
        exit 1
    fi
    
    echo "FreeRADIUS is healthy"
    exit 0
}

main "$@"
