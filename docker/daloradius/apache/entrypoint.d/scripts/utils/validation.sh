#!/bin/bash

# Validation utility functions

validate_environment() {
    # Check required environment variables
    local required_vars=(
        "DALORADIUS_DB_HOST"
        "DALORADIUS_DB_USER"
        "DALORADIUS_DB_PASS"
        "DALORADIUS_DB_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_warn "Environment variable $var is not set"
        fi
    done
    
    return 0
}

validate_dependencies() {
    # Check if required binaries exist
    local required_bins=(
        "/usr/local/apache2/bin/httpd"
        "/usr/local/bin/php"
    )
    
    for bin in "${required_bins[@]}"; do
        if [ ! -x "$bin" ]; then
            log_error "Required binary not found: $bin"
            return 1
        fi
    done
    
    return 0
}
