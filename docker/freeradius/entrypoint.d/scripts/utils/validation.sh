#!/bin/bash
# validation.sh - Validation utilities for FreeRADIUS container

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

validate_environment() {
    log_debug "Validating environment variables"
    
    if [[ -n "${RADIUS_AUTH_PORT:-}" ]]; then
        if ! [[ "$RADIUS_AUTH_PORT" =~ ^[0-9]+$ ]] || [ "$RADIUS_AUTH_PORT" -lt 1 ] || [ "$RADIUS_AUTH_PORT" -gt 65535 ]; then
            log_error "Invalid RADIUS_AUTH_PORT: $RADIUS_AUTH_PORT"
            return 1
        fi
    fi
    
    if [[ -n "${RADIUS_ACCT_PORT:-}" ]]; then
        if ! [[ "$RADIUS_ACCT_PORT" =~ ^[0-9]+$ ]] || [ "$RADIUS_ACCT_PORT" -lt 1 ] || [ "$RADIUS_ACCT_PORT" -gt 65535 ]; then
            log_error "Invalid RADIUS_ACCT_PORT: $RADIUS_ACCT_PORT"
            return 1
        fi
    fi
    
    if [[ -n "${RADIUS_STATUS_PORT:-}" ]]; then
        if ! [[ "$RADIUS_STATUS_PORT" =~ ^[0-9]+$ ]] || [ "$RADIUS_STATUS_PORT" -lt 1 ] || [ "$RADIUS_STATUS_PORT" -gt 65535 ]; then
            log_error "Invalid RADIUS_STATUS_PORT: $RADIUS_STATUS_PORT"
            return 1
        fi
    fi
    
    if [[ -n "${RADIUS_TIMEOUT:-}" ]]; then
        if ! [[ "$RADIUS_TIMEOUT" =~ ^[0-9]+$ ]]; then
            log_error "Invalid RADIUS_TIMEOUT: $RADIUS_TIMEOUT"
            return 1
        fi
    fi
    
    local valid_auth_types=("files" "sql" "ldap" "pam")
    if [[ -n "${RADIUS_AUTH_TYPE:-}" ]]; then
        if [[ ! " ${valid_auth_types[@]} " =~ " ${RADIUS_AUTH_TYPE} " ]]; then
            log_error "Invalid RADIUS_AUTH_TYPE: $RADIUS_AUTH_TYPE. Valid options: ${valid_auth_types[*]}"
            return 1
        fi
    fi
    
    if [[ "${RADIUS_AUTH_TYPE:-files}" == "sql" ]] && [[ "${DB_ENABLE:-false}" != "true" ]]; then
        log_warn "RADIUS_AUTH_TYPE is 'sql' but DB_ENABLE is not 'true'"
    fi
    
    if [[ "${RADIUS_AUTH_TYPE:-files}" == "ldap" ]] && [[ "${LDAP_ENABLE:-false}" != "true" ]]; then
        log_warn "RADIUS_AUTH_TYPE is 'ldap' but LDAP_ENABLE is not 'true'"
    fi
    
    if [[ "${DB_ENABLE:-false}" == "true" ]]; then
        if [[ -z "${DB_HOST:-}" ]]; then
            log_error "DB_ENABLE is true but DB_HOST is not set"
            return 1
        fi
        if [[ -z "${DB_NAME:-}" ]]; then
            log_error "DB_ENABLE is true but DB_NAME is not set"
            return 1
        fi
        if [[ -z "${DB_USER:-}" ]]; then
            log_error "DB_ENABLE is true but DB_USER is not set"
            return 1
        fi
        if [[ -z "${DB_PASS:-}" ]]; then
            log_error "DB_ENABLE is true but DB_PASS is not set"
            return 1
        fi
    fi
    
    if [[ "${LDAP_ENABLE:-false}" == "true" ]]; then
        if [[ -z "${LDAP_SERVER:-}" ]]; then
            log_error "LDAP_ENABLE is true but LDAP_SERVER is not set"
            return 1
        fi
        if [[ -z "${LDAP_BASE_DN:-}" ]]; then
            log_error "LDAP_ENABLE is true but LDAP_BASE_DN is not set"
            return 1
        fi
    fi
    
    log_debug "Environment validation passed"
    return 0
}

validate_dependencies() {
    log_debug "Validating dependencies"
    
    local required_commands=("radiusd")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: $cmd"
            return 1
        fi
    done
    
    log_debug "Dependency validation passed"
    return 0
}

validate_ports() {
    log_debug "Validating port availability"
    
    local ports=("${RADIUS_AUTH_PORT:-1812}" "${RADIUS_ACCT_PORT:-1813}")
    [[ -n "${RADIUS_STATUS_PORT:-}" ]] && ports+=("$RADIUS_STATUS_PORT")
    
    for port in "${ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warn "Port $port may already be in use"
        fi
    done
    
    return 0
}
