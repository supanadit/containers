#!/bin/bash
# security.sh - Security utilities for FreeRADIUS container

set -euo pipefail

set_secure_permissions() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        chmod 640 "$file" 2>/dev/null || chmod 644 "$file"
    elif [[ -d "$file" ]]; then
        chmod 755 "$file" 2>/dev/null || chmod 755 "$file"
    fi
}

set_owner() {
    local path="$1"
    local user="${2:-freerad}"
    local group="${3:-$user}"
    
    if id "$user" &>/dev/null; then
        chown -R "$user:$group" "$path" 2>/dev/null || true
    fi
}

check_default_credentials() {
    local user_name="${FREERADIUS_USER_NAME:-admin}"
    local user_password="${FREERADIUS_USER_PASSWORD:-admin}"
    
    if [[ "$user_name" == "admin" ]] && [[ "$user_password" == "admin" ]]; then
        log_warn "=========================================="
        log_warn "WARNING: Using default credentials (admin/admin)"
        log_warn "Please change FREERADIUS_USER_PASSWORD in production!"
        log_warn "=========================================="
    fi
}

check_default_secret() {
    local default_secret="${RADIUS_DEFAULT_SECRET:-secret}"
    
    if [[ "$default_secret" == "secret" ]]; then
        log_warn "=========================================="
        log_warn "WARNING: Using default client secret 'secret'"
        log_warn "Please change RADIUS_DEFAULT_SECRET in production!"
        log_warn "=========================================="
    fi
    
    if [[ "$default_secret" == "testing123" ]]; then
        log_warn "=========================================="
        log_warn "WARNING: Using well-known secret 'testing123'"
        log_warn "This is a security risk! Change it immediately!"
        log_warn "=========================================="
    fi
}

validate_secret_strength() {
    local secret="$1"
    
    if [[ ${#secret} -lt 8 ]]; then
        log_warn "Client secret is too short (minimum 8 characters recommended)"
        return 1
    fi
    
    return 0
}

sanitize_input() {
    local input="$1"
    echo "$input" | sed -e 's/[^a-zA-Z0-9._-]/_/g'
}
