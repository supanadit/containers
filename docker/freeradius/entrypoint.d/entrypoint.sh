#!/bin/bash
# entrypoint.sh - Main container orchestrator
# Coordinates all modular scripts for FreeRADIUS container initialization and runtime

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

SCRIPT_VERSION="1.0.0"

export PATH="/usr/local/freeradius/sbin:/usr/local/freeradius/bin:$PATH"

export RADIUS_LISTEN_ADDR="${RADIUS_LISTEN_ADDR:-*}"
export RADIUS_AUTH_PORT="${RADIUS_AUTH_PORT:-1812}"
export RADIUS_ACCT_PORT="${RADIUS_ACCT_PORT:-1813}"
export RADIUS_STATUS_PORT="${RADIUS_STATUS_PORT:-}"
export RADIUS_TIMEOUT="${RADIUS_TIMEOUT:-30}"
export RADIUS_MAX_REQUEST="${RADIUS_MAX_REQUEST:-4096}"
export RADIUS_MAX_ATTRIBUTES="${RADIUS_MAX_ATTRIBUTES:-200}"
export RADIUS_DEFAULT_SECRET="${RADIUS_DEFAULT_SECRET:-secret}"
export RADIUS_CLIENTS="${RADIUS_CLIENTS:-}"
export RADIUS_CLIENT_NETWORK="${RADIUS_CLIENT_NETWORK:-}"
export RADIUS_AUTH_TYPE="${RADIUS_AUTH_TYPE:-files}"
export FREERADIUS_USER_NAME="${FREERADIUS_USER_NAME:-admin}"
export FREERADIUS_USER_PASSWORD="${FREERADIUS_USER_PASSWORD:-admin}"
export DB_ENABLE="${DB_ENABLE:-false}"
export DB_TYPE="${DB_TYPE:-mysql}"
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-3306}"
export DB_NAME="${DB_NAME:-radius}"
export DB_USER="${DB_USER:-radius}"
export DB_PASS="${DB_PASS:-}"
export DB_POOL_MAX="${DB_POOL_MAX:-20}"
export LDAP_ENABLE="${LDAP_ENABLE:-false}"
export LDAP_SERVER="${LDAP_SERVER:-}"
export LDAP_PORT="${LDAP_PORT:-389}"
export LDAP_IDENTITY="${LDAP_IDENTITY:-}"
export LDAP_PASSWORD="${LDAP_PASSWORD:-}"
export LDAP_BASE_DN="${LDAP_BASE_DN:-}"
export RADIUS_DEBUG="${RADIUS_DEBUG:-no}"
export RADIUS_LOG_LEVEL="${RADIUS_LOG_LEVEL:-info}"
export FREERADIUS_TIMEZONE="${FREERADIUS_TIMEZONE:-UTC}"
export SLEEP_MODE="${SLEEP_MODE:-false}"

normalize_bool() {
    local value="${1:-}"
    case "${value,,}" in
        true|1|yes|on)
            echo "true"
            ;;
        false|0|no|off)
            echo "false"
            ;;
        *)
            echo ""
            ;;
    esac
}

sleep_mode_raw="${SLEEP_MODE:-false}"
case "${sleep_mode_raw,,}" in
    true|1|yes|on)
        SLEEP_MODE="true"
        ;;
    *)
        SLEEP_MODE="false"
        ;;
esac
export SLEEP_MODE

main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"
    
    log_info "FreeRADIUS Container Entrypoint v$SCRIPT_VERSION"
    log_environment
    
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi
    
    setup_signal_handlers
    
    run_initialization
    
    start_runtime
    
    log_script_end "entrypoint.sh"
}

setup_signal_handlers() {
    log_debug "Setting up signal handlers"
    
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP
    
    log_debug "Signal handlers configured"
}

handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"
    
    if [[ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi
    
    log_info "Shutdown complete"
    exit 0
}

run_initialization() {
    log_info "Running initialization scripts"
    
    if [[ "$SLEEP_MODE" == "true" ]]; then
        log_info "=========================================="
        log_info "SLEEP MODE ENABLED"
        log_info "FreeRADIUS will not start"
        log_info "Container is running for maintenance purposes"
        log_info "=========================================="
        
        if [[ -f "/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh" ]]; then
            chmod +x /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh
        fi
        
        exec tail -f /dev/null
    fi
    
    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/01-directories.sh"
        "/opt/container/entrypoint.d/scripts/init/02-config.sh"
        "/opt/container/entrypoint.d/scripts/init/03-users.sh"
    )
    
    for script in "${init_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log_info "Running initialization script: $(basename "$script")"
            if ! "$script"; then
                log_error "Initialization script failed: $(basename "$script")"
                exit 1
            fi
        else
            log_warn "Initialization script not found: $script"
        fi
    done
    
    log_info "All initialization scripts completed successfully"
}

start_runtime() {
    log_info "Starting runtime management"
    
    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"
    
    if [[ -f "$startup_script" ]]; then
        chmod +x "$startup_script"
        log_info "Starting FreeRADIUS via startup script"
        exec "$startup_script"
    else
        log_error "Startup script not found: $startup_script"
        exit 1
    fi
}

main "$@"
