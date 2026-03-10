#!/bin/bash
# shutdown.sh - Graceful shutdown of FreeRADIUS server

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

main() {
    log_info "Shutting down FreeRADIUS server"
    
    local pidfile="/usr/local/freeradius/run/radiusd.pid"
    
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null || echo "")
        
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_info "Sending SIGTERM to FreeRADIUS (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            
            local timeout=10
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt $timeout ]]; do
                sleep 1
                ((count++))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "FreeRADIUS did not stop gracefully, sending SIGKILL"
                kill -KILL "$pid" 2>/dev/null || true
            fi
            
            log_info "FreeRADIUS stopped"
        else
            log_debug "FreeRADIUS process not found or already stopped"
        fi
    else
        log_debug "PID file not found: $pidfile"
        
        if pgrep -x radiusd &>/dev/null; then
            log_warn "FreeRADIUS running but no PID file, killing processes"
            pkill -TERM radiusd 2>/dev/null || true
            sleep 2
            pkill -KILL radiusd 2>/dev/null || true
        fi
    fi
    
    log_info "Shutdown complete"
}

main "$@"
