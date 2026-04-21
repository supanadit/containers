#!/bin/bash
# logging.sh - Structured logging utility functions
# Provides consistent logging across all container scripts

set -euo pipefail

LOG_LEVEL="${LOG_LEVEL:-INFO}"

declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

is_log_level_enabled() {
    local requested_level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local requested_value="${LOG_LEVELS[$requested_level]:-1}"
    [ "$requested_value" -ge "$current_level" ]
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)
    if is_log_level_enabled "$level"; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

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

log_with_context() {
    local level="$1"
    local message="$2"
    local context="${FUNCNAME[1]:-unknown}:${BASH_LINENO[0]:-unknown}"
    log_message "$level" "[$context] $message"
}

debug_with_context() {
    log_with_context "DEBUG" "$*"
}

info_with_context() {
    log_with_context "INFO" "$*"
}

warn_with_context() {
    log_with_context "WARN" "$*"
}

error_with_context() {
    log_with_context "ERROR" "$*" >&2
}

log_script_start() {
    local script_name="${1:-${BASH_SOURCE[1]##*/}}"
    log_info "Starting script: $script_name"
}

log_script_end() {
    local script_name="${1:-${BASH_SOURCE[1]##*/}}"
    local exit_code="${2:-$?}"
    if [ "$exit_code" -eq 0 ]; then
        log_info "Completed script: $script_name"
    else
        log_error "Failed script: $script_name (exit code: $exit_code)"
    fi
}

log_environment() {
    if is_log_level_enabled "DEBUG"; then
        log_debug "Environment variables:"
        log_debug "  KAFKA_DATA_DIR=${KAFKA_DATA_DIR:-not set}"
        log_debug "  KAFKA_LOG_LEVEL=${KAFKA_LOG_LEVEL:-not set}"
        log_debug "  KAFKA_NODE_ID=${KAFKA_NODE_ID:-not set}"
        log_debug "  KAFKA_PROCESS_ROLES=${KAFKA_PROCESS_ROLES:-not set}"
        log_debug "  KAFKA_CONTROLLER_QUORUM_VOTERS=${KAFKA_CONTROLLER_QUORUM_VOTERS:-not set}"
        log_debug "  KAFKA_ADVERTISED_LISTENERS=${KAFKA_ADVERTISED_LISTENERS:-not set}"
        log_debug "  LOG_LEVEL=${LOG_LEVEL:-not set}"
        log_debug "  KAFKA_SLEEP_MODE=${KAFKA_SLEEP_MODE:-not set}"
        log_debug "  TIMEOUT=${TIMEOUT:-not set}"
    fi
}

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
