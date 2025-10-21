#!/bin/bash
# 04-https.sh - Configure HTTPS settings

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/wordpress.sh

log_info "Configuring HTTPS settings"

# If IS_HTTPS is true, add HTTPS configuration to wp-config.php
if [ "${IS_HTTPS:-false}" = "true" ]; then
    log_info "Enabling HTTPS configuration"
    add_https_config /var/www/html/wp-config.php
else
    log_info "Disabling HTTPS configuration"
    remove_https_config /var/www/html/wp-config.php
fi

log_info "HTTPS configuration completed"