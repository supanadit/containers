#!/bin/bash
# 11-permissions.sh - Set file and directory permissions

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Setting file and directory permissions"

# Custom Stateless .php copy
if [ "${IS_STATELESS:-false}" = "true" ]; then
    log_info "Processing stateless file copies"
    # Handle STATELESS_FILE_<name>
    for var in $(compgen -A variable | grep '^STATELESS_FILE_'); do
        # Check if the variable is valid
        # For example STATELESS_FILE_OBJECT_CACHE: object-cache.php
        # It will copy /content/stateless/object-cache.php to /var/www/html/wp-content/object-cache.php
        # But first it will check /content/stateless/object-cache.php exist, if not it will skipped
        var_name=${var#STATELESS_FILE_}
        var_value="${!var}"
        if [ -f "/content/stateless/${var_value}" ]; then
            log_info "Copying stateless file: $var_value"
            cp "/content/stateless/${var_value}" "/var/www/html/wp-content/"
            chown www-data:www-data "/var/www/html/wp-content/${var_value}"
        else
            log_info "Stateless file not found, skipping: $var_value"
        fi
    done
fi

log_info "Setting WordPress directory permissions"
chmod 777 -R /var/www/html
chown www-data:www-data /var/www/html/wp-config.php

log_info "Permissions configuration completed"