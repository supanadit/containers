#!/bin/bash
# logging.sh - Logging utilities for MaxScale container

# Log levels
LOG_DEBUG=0
LOG_INFO=1
LOG_WARN=2
LOG_ERROR=3

# Default log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Color codes for output
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_GRAY='\033[0;90m'

# Get log level number
get_log_level() {
    case "$LOG_LEVEL" in
        DEBUG) echo 0 ;;
        INFO) echo 1 ;;
        WARN) echo 2 ;;
        ERROR) echo 3 ;;
        *) echo 1 ;;
    esac
}

# Check if should log at given level
should_log() {
    local level="$1"
    local current_level=$(get_log_level)
    local message_level

    case "$level" in
        DEBUG) message_level=0 ;;
        INFO) message_level=1 ;;
        WARN) message_level=2 ;;
        ERROR) message_level=3 ;;
        *) message_level=1 ;;
    esac

    [ "$message_level" -ge "$current_level" ]
}

# Format log message
format_log() {
    local level="$1"
    local message="$2"
    local color

    case "$level" in
        DEBUG) color="$COLOR_GRAY" ;;
        INFO) color="$COLOR_BLUE" ;;
        WARN) color="$COLOR_YELLOW" ;;
        ERROR) color="$COLOR_RED" ;;
        *) color="$COLOR_RESET" ;;
    esac

    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${COLOR_RESET}"
}

# Logging functions
log_debug() {
    if should_log "DEBUG"; then
        format_log "DEBUG" "$@" >&2
    fi
}

log_info() {
    if should_log "INFO"; then
        format_log "INFO" "$@" >&2
    fi
}

log_warn() {
    if should_log "WARN"; then
        format_log "WARN" "$@" >&2
    fi
}

log_error() {
    if should_log "ERROR"; then
        format_log "ERROR" "$@" >&2
    fi
}

log_script_start() {
    log_info "========== START: $@ =========="
}

log_script_end() {
    log_info "========== END: $@ =========="
}

log_environment() {
    if should_log "DEBUG"; then
        log_debug "Environment variables:"
        for var in MAXSCALE_CONFIG_DIR MAXSCALE_DATA_DIR MAXSCALE_LOG_DIR MAXSCALE_ADMIN_USER MAXSCALE_ADMIN_PASSWORD MAXSCALE_SERVICE_READWRITE_ROUTES MAXSCALE_SERVICE_READCONN_ROUTES MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS; do
            local value="${!var}"
            if [ -n "$value" ]; then
                if [ "$var" = "MAXSCALE_ADMIN_PASSWORD" ]; then
                    log_debug "  $var=****"
                else
                    log_debug "  $var=$value"
                fi
            fi
        done
    fi
}