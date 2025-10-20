#!/bin/bash
# validation.sh - Validation utilities for WordPress container

# Validate required environment variables
validate_environment() {
    local required_vars=("WORDPRESS_DB_NAME" "WORDPRESS_DB_USER" "WORDPRESS_DB_PASSWORD" "WORDPRESS_DB_HOST")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    log_info "Environment validation passed"
    return 0
}

# Validate dependencies
validate_dependencies() {
    # Check if required commands exist
    local required_commands=("awk" "sed" "curl" "chown" "chmod")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    # Check if WordPress files exist
    if [ ! -f "/var/www/html/wp-config-sample.php" ]; then
        log_error "WordPress sample config not found at /var/www/html/wp-config-sample.php"
        return 1
    fi

    log_info "Dependency validation passed"
    return 0
}