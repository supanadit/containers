#!/bin/bash
# 01-directories.sh - Directory setup for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh

log_script_start "01-directories.sh"

# Data directory
export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"
export MARIADB_CONFIG_DIR="${MARIADB_CONFIG_DIR:-/etc/mysql/mariadb.conf.d}"
export MARIADB_LOG_DIR="${MARIADB_LOG_DIR:-/var/log/mariadb}"
export MARIADB_RUN_DIR="${MARIADB_RUN_DIR:-/run/mariadb}"
export MARIADB_BACKUP_DIR="${MARIADB_BACKUP_DIR:-/var/lib/mariadb/backup}"

# Create all required directories
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

# Create SSL directory if SSL is enabled
if [ "${MARIADB_SSL_ENABLE:-false}" = "true" ]; then
    local ssl_dir="/var/lib/mysql/ssl"
    mkdir -p "$ssl_dir"
    chown mysql:mysql "$ssl_dir"
    chmod 0700 "$ssl_dir"
fi

log_script_end "01-directories.sh"