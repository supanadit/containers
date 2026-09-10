#!/bin/bash
# 01-directories.sh - Directory setup for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh

log_script_start "01-directories.sh"

setup_directories() {
    export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/opt/containers/data}"
    export MARIADB_CONFIG_DIR="${MARIADB_CONFIG_DIR:-/opt/containers/config}"
    export MARIADB_LOG_DIR="${MARIADB_LOG_DIR:-/opt/containers/logs}"
    export MARIADB_RUN_DIR="${MARIADB_RUN_DIR:-/opt/containers/run}"
    export MARIADB_BACKUP_DIR="${MARIADB_BACKUP_DIR:-/opt/containers/backup}"

    local directories=(
        "$MARIADB_DATA_DIR"
        "$MARIADB_CONFIG_DIR"
        "$MARIADB_LOG_DIR"
        "$MARIADB_RUN_DIR"
        "$MARIADB_BACKUP_DIR"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            log_info "Creating directory: $dir"
            mkdir -p "$dir"
            chown mysql:mysql "$dir"
            chmod 0755 "$dir"
        fi
    done

    if [ "${MARIADB_SSL_ENABLE:-false}" = "true" ]; then
        local ssl_dir="/opt/containers/config/ssl"
        mkdir -p "$ssl_dir"
        chown mysql:mysql "$ssl_dir"
        chmod 0700 "$ssl_dir"
    fi

    log_script_end "01-directories.sh"
}

setup_directories