#!/bin/bash
# 02-wordpress-vars.sh - Handle WORDPRESS_ environment variables

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/wordpress.sh

log_info "Processing WORDPRESS_ environment variables"

# Detect all WORDPRESS_<name> variables and update wp-config.php
for var in $(compgen -A variable | grep '^WORDPRESS_'); do
    var_name=${var#WORDPRESS_}
    var_value="${!var}"

    log_debug "Processing WORDPRESS_$var_name = $var_value"
    update_wp_config_define /var/www/html/wp-config.php "$var_name" "$var_value"
done

log_info "WORDPRESS_ environment variables processing completed"