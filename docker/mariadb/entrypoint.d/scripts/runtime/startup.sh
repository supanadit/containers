#!/bin/bash
# startup.sh - MariaDB startup script

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_script_start "startup.sh"

export PATH="/usr/local/mariadb/bin:$PATH"
export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"
export MARIADB_RUN_DIR="${MARIADB_RUN_DIR:-/run/mariadb}"

log_info "Starting MariaDB server"
log_info "Data dir: $MARIADB_DATA_DIR"
log_info "Run dir: $MARIADB_RUN_DIR"

mkdir -p "$MARIADB_RUN_DIR"
mkdir -p /run/mysqld
chown -R mysql:mysql "$MARIADB_DATA_DIR"
chown -R mysql:mysql "$MARIADB_RUN_DIR"
chown mysql:mysql /run/mysqld

log_info "Checking directories..."
ls -la /run/ 2>&1 | head -5
ls -la "$MARIADB_DATA_DIR" 2>&1 | head -5

log_info "Launching mariadbd..."
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket=/run/mysqld/mysqld.sock