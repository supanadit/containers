#!/bin/bash

# Logging utility functions

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_environment() {
    log_debug "Environment variables:"
    log_debug "  DALORADIUS_DB_HOST: ${DALORADIUS_DB_HOST:-mysql}"
    log_debug "  DALORADIUS_DB_USER: ${DALORADIUS_DB_USER:-radius}"
    log_debug "  DALORADIUS_DB_NAME: ${DALORADIUS_DB_NAME:-radius}"
    log_debug "  DALORADIUS_FREERADIUS_VERSION: ${DALORADIUS_FREERADIUS_VERSION:-3}"
}
