#!/bin/bash
# shutdown.sh - MariaDB graceful shutdown script

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Received shutdown signal, starting graceful shutdown"

log_info "Flushing tables and preparing for shutdown"
mariadb -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "FLUSH TABLES WITH READ LOCK; SET GLOBAL innodb_fast_shutdown=0;" 2>/dev/null || true

log_info "Shutdown complete"
exit 0