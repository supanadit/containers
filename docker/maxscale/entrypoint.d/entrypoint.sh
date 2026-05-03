#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "MaxScale container entrypoint"

export MAXSCALE_CONFIG_DIR="${MAXSCALE_CONFIG_DIR:-/var/lib/maxscale}"
export MAXSCALE_DATA_DIR="${MAXSCALE_DATA_DIR:-/var/lib/maxscale/data}"
export MAXSCALE_LOG_DIR="${MAXSCALE_LOG_DIR:-/var/log/maxscale}"

mkdir -p "$MAXSCALE_CONFIG_DIR" "$MAXSCALE_DATA_DIR" "$MAXSCALE_LOG_DIR"

MAXSCALE_ADMIN_USER="${MAXSCALE_ADMIN_USER:-admin}"
MAXSCALE_ADMIN_PASSWORD="${MAXSCALE_ADMIN_PASSWORD:-mariadb}"

cat > /etc/maxscale.cnf.d/generated.cnf << MAXSCALE_CONFIG
[maxscale]
threads=auto
admin_auth=true
admin_username=$MAXSCALE_ADMIN_USER
admin_password=$MAXSCALE_ADMIN_PASSWORD

[services]
MAXSCALE_SERVICE_READWRITE_ROUTES=${MAXSCALE_SERVICE_READWRITE_ROUTES:-localhost:3306}
MAXSCALE_SERVICE_READCONN_ROUTES=${MAXSCALE_SERVICE_READCONN_ROUTES:-localhost:3306}

[monitors]
MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS=${MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS:-localhost:3306}

[servers]
localhost=localhost:3306
MAXSCALE_CONFIG

log_info "Starting MaxScale"
exec maxscale -f /etc/maxscale.cnf.d/generated.cnf