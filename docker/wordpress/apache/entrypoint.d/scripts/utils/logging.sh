#!/bin/bash
# logging.sh - Logging utilities for WordPress container

# Set up logging functions
log_script_start() {
    local script_name="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting $script_name" >&2
}

log_script_end() {
    local script_name="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Completed $script_name" >&2
}

log_info() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >&2
}

log_warn() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $message" >&2
}

log_error() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >&2
}

log_debug() {
    local message="$1"
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $message" >&2
    fi
}

log_environment() {
    log_debug "Environment variables:"
    log_debug "WORDPRESS_DB_NAME: ${WORDPRESS_DB_NAME:-}"
    log_debug "WORDPRESS_DB_USER: ${WORDPRESS_DB_USER:-}"
    log_debug "WORDPRESS_DB_HOST: ${WORDPRESS_DB_HOST:-}"
    log_debug "IS_STATELESS: ${IS_STATELESS:-false}"
    log_debug "IS_HTTPS: ${IS_HTTPS:-false}"
    log_debug "PHP_MEMORY_LIMIT: ${PHP_MEMORY_LIMIT:-}"
    log_debug "APACHE_MPM: ${APACHE_MPM:-event}"
    log_debug "APACHE_STATUS: ${APACHE_STATUS:-false}"
    log_debug "APACHE_EXPORTER: ${APACHE_EXPORTER:-false}"
}