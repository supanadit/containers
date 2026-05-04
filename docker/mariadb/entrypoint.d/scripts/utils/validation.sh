#!/bin/bash
# validation.sh - Environment and dependency validation for MariaDB container

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

# Validate required environment variables
validate_environment() {
    log_info "Validating environment variables"

    local errors=()

    # Check required variables based on mode
    if [ "${MARIADB_ALLOW_EMPTY_PASSWORD:-no}" != "yes" ]; then
        if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
            errors+=("MARIADB_ROOT_PASSWORD is required when MARIADB_ALLOW_EMPTY_PASSWORD is not 'yes'")
        fi
    fi

    # Validate replication variables if replication is enabled
    if [ "${MARIADB_REPLICATION_ENABLE:-false}" = "true" ]; then
        if [ -z "${MARIADB_REPLICATION_USER:-}" ]; then
            errors+=("MARIADB_REPLICATION_USER is required for replication")
        fi
        if [ -z "${MARIADB_REPLICATION_PASSWORD:-}" ]; then
            errors+=("MARIADB_REPLICATION_PASSWORD is required for replication")
        fi
    fi

    # Validate Galera variables if Galera is enabled
    if [ "${MARIADB_GALERA_ENABLE:-false}" = "true" ]; then
        if [ -z "${MARIADB_GALERA_CLUSTER_NAME:-}" ]; then
            errors+=("MARIADB_GALERA_CLUSTER_NAME is required for Galera cluster")
        fi
        if [ -z "${MARIADB_GALERA_SEEDS:-}" ]; then
            errors+=("MARIADB_GALERA_SEEDS is required for Galera cluster (format: host1:port,host2:port,...)")
        fi
    fi

    # Validate backup variables if backup is enabled
    if [ "${MARIADB_BACKUP_ENABLE:-false}" = "true" ]; then
        if [ -z "${MARIADB_BACKUP_METHOD:-}" ]; then
            errors+=("MARIADB_BACKUP_METHOD is required for backup (xtrabackup or mariabackup)")
        fi
    fi

    # Report errors if any
    if [ ${#errors[@]} -gt 0 ]; then
        log_error "Environment validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi

    log_info "Environment validation passed"
    return 0
}

# Validate required dependencies
validate_dependencies() {
    log_info "Validating dependencies"

    export PATH="/usr/local/mariadb/bin:/usr/local/mariadb/scripts:$PATH"

    local missing=()
    local required_commands=("mariadbd" "mariadb" "mariadb-install-db")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi

    log_info "All required dependencies are available"
    return 0
}

# Validate data directory
validate_data_directory() {
    local data_dir="${MARIADB_DATA_DIR:-/var/lib/mysql}"

    if [ ! -d "$data_dir" ]; then
        log_warn "Data directory $data_dir does not exist, will be created"
        return 0
    fi

    # Check if directory is writable
    if [ ! -w "$data_dir" ]; then
        log_error "Data directory $data_dir is not writable"
        return 1
    fi

    return 0
}

# Validate SSL configuration
validate_ssl() {
    if [ "${MARIADB_SSL_ENABLE:-false}" = "true" ]; then
        local cert_dir="${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}"
        local required_files=("server.crt" "server.key" "ca.crt")

        for file in "${required_files[@]}"; do
            if [ ! -f "$cert_dir/$file" ]; then
                log_error "SSL file $cert_dir/$file is required when SSL is enabled"
                return 1
            fi
        done
    fi

    return 0
}