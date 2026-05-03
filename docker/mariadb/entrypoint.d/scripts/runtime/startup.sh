#!/bin/bash
# startup.sh - MariaDB startup script

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_script_start "startup.sh"

export PATH="/usr/local/mariadb/bin:$PATH"
export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"

log_info "Starting MariaDB server"

chown -R mysql:mysql "$MARIADB_DATA_DIR"

local galera_enabled="${MARIADB_GALERA_ENABLE:-false}"

if [ "$galera_enabled" = "true" ]; then
    log_info "Starting MariaDB in Galera mode"
    exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --console
else
    log_info "Starting MariaDB in standalone mode"
    exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --console
fi

log_script_end "startup.sh"