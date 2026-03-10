#!/bin/bash
# logging.sh - Logging utilities for FreeRADIUS container

set -euo pipefail

LOG_LEVEL="${RADIUS_LOG_LEVEL:-info}"
LOG_FILE="${LOG_FILE:-/usr/local/freeradius/log/radius.log}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-yes}"

log_debug() {
    local message="$1"
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        log_message "DEBUG" "$message"
    fi
}

log_info() {
    local message="$1"
    log_message "INFO" "$message"
}

log_warn() {
    local message="$1"
    log_message "WARN" "$message" >&2
}

log_error() {
    local message="$1"
    log_message "ERROR" "$message" >&2
}

log_message() {
    local level="$1"
    local message="$2"
    local output="${message}"
    
    if [[ "$LOG_TIMESTAMP" == "yes" ]]; then
        local timestamp
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        output="[${timestamp}] [${level}] ${message}"
    else
        output="[${level}] ${message}"
    fi
    
    echo "$output"
    
    if [[ -n "$LOG_FILE" ]] && [[ -d "$(dirname "$LOG_FILE")" ]]; then
        echo "$output" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_script_start() {
    local script_name="$1"
    log_info "=========================================="
    log_info "Starting: ${script_name}"
    log_info "=========================================="
}

log_script_end() {
    local script_name="$1"
    log_info "=========================================="
    log_info "Completed: ${script_name}"
    log_info "=========================================="
}

log_environment() {
    log_debug "Environment variables:"
    log_debug "  RADIUS_LISTEN_ADDR: ${RADIUS_LISTEN_ADDR:-}"
    log_debug "  RADIUS_AUTH_PORT: ${RADIUS_AUTH_PORT:-}"
    log_debug "  RADIUS_ACCT_PORT: ${RADIUS_ACCT_PORT:-}"
    log_debug "  RADIUS_AUTH_TYPE: ${RADIUS_AUTH_TYPE:-}"
    log_debug "  RADIUS_DEBUG: ${RADIUS_DEBUG:-}"
    log_debug "  FREERADIUS_USER_NAME: ${FREERADIUS_USER_NAME:-}"
    log_debug "  DB_ENABLE: ${DB_ENABLE:-}"
    log_debug "  LDAP_ENABLE: ${LDAP_ENABLE:-}"
    log_debug "  SLEEP_MODE: ${SLEEP_MODE:-}"
}
