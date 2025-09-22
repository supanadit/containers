#!/bin/bash
# logging.sh - Structured logging utility functions
# Provides consistent logging across all container scripts

# Set strict error handling
set -euo pipefail

# Default log level if not set
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Log levels (in order of verbosity)
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# Get current timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Check if log level is enabled
is_log_level_enabled() {
    local requested_level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local requested_value="${LOG_LEVELS[$requested_level]:-1}"

    [ "$requested_value" -ge "$current_level" ]
}

# Core logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)

    # Only log if level is enabled
    if is_log_level_enabled "$level"; then
        echo "[$timestamp] [$level] $message"
    fi
}

# Public logging functions
log_debug() {
    log_message "DEBUG" "$*"
}

log_info() {
    log_message "INFO" "$*"
}

log_warn() {
    log_message "WARN" "$*"
}

log_error() {
    log_message "ERROR" "$*" >&2
}

# Log with context (function name, line number)
log_with_context() {
    local level="$1"
    local message="$2"
    local context="${FUNCNAME[1]:-unknown}:${BASH_LINENO[0]:-unknown}"

    log_message "$level" "[$context] $message"
}

# Debug logging with context
debug_with_context() {
    log_with_context "DEBUG" "$*"
}

# Info logging with context
info_with_context() {
    log_with_context "INFO" "$*"
}

# Warning logging with context
warn_with_context() {
    log_with_context "WARN" "$*"
}

# Error logging with context
error_with_context() {
    log_with_context "ERROR" "$*" >&2
}

# Log script execution start
log_script_start() {
    local script_name="${1:-${BASH_SOURCE[1]##*/}}"
    log_info "Starting script: $script_name"
}

# Log script execution end
log_script_end() {
    local script_name="${1:-${BASH_SOURCE[1]##*/}}"
    local exit_code="${2:-$?}"
    if [ "$exit_code" -eq 0 ]; then
        log_info "Completed script: $script_name"
    else
        log_error "Failed script: $script_name (exit code: $exit_code)"
    fi
}

# Log environment information (for debugging)
log_environment() {
    if is_log_level_enabled "DEBUG"; then
        log_debug "Environment variables:"
        log_debug "  PGDATA=${PGDATA:-not set}"
        log_debug "  PGCONFIG=${PGCONFIG:-not set}"
        log_debug "  LOG_LEVEL=${LOG_LEVEL:-not set}"
        log_debug "  USE_PATRONI=${USE_PATRONI:-not set}"
        log_debug "  SLEEP_MODE=${SLEEP_MODE:-not set}"
        log_debug "  TIMEOUT=${TIMEOUT:-not set}"
    fi
}

# Export functions for use by other scripts
export -f get_timestamp
export -f is_log_level_enabled
export -f log_message
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_with_context
export -f debug_with_context
export -f info_with_context
export -f warn_with_context
export -f error_with_context
export -f log_script_start
export -f log_script_end
export -f log_environment