#!/bin/bash
# 05-table-prefix.sh - Configure WordPress table prefix

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/wordpress.sh

log_info "Configuring table prefix"

# If has table prefix with variable CUSTOM_TABLE_PREFIX
if [ -n "${CUSTOM_TABLE_PREFIX:-}" ]; then
    log_info "Setting custom table prefix: $CUSTOM_TABLE_PREFIX"
    update_table_prefix /var/www/html/wp-config.php "$CUSTOM_TABLE_PREFIX"
else
    log_info "Using default table prefix"
fi

log_info "Table prefix configuration completed"