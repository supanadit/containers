#!/bin/bash
# 11-permissions.sh - Early setup and stateless file handling

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Performing early WordPress setup"

# Custom Stateless .php copy - this needs to happen early before volume mounts
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

# Basic permission setup for main WordPress directory
# More comprehensive permissions will be set in startup.sh after volume mounts
chmod 755 /var/www/html 2>/dev/null || true
chown www-data:www-data /var/www/html 2>/dev/null || true

# Ensure wp-config.php has correct permissions if it exists
if [ -f "/var/www/html/wp-config.php" ]; then
    chown www-data:www-data /var/www/html/wp-config.php 2>/dev/null || true
    chmod 644 /var/www/html/wp-config.php 2>/dev/null || true
fi

log_info "Early setup completed - comprehensive permissions will be set at startup"