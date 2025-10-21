#!/bin/bash
# 01-wp-config.sh - Initialize WordPress configuration

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/wordpress.sh

log_info "Initializing WordPress configuration"

# Create wp-config.php if it doesn't exist in /var/www/html
if [ ! -f /var/www/html/wp-config.php ]; then
    log_info "Creating wp-config.php from sample"
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    # Update database settings
    update_wp_config_database /var/www/html/wp-config.php

    # Only replace salts if placeholders are present
    if grep -q "put your unique phrase here" /var/www/html/wp-config.php; then
        log_info "Generating and updating WordPress salts"
        salts=$(generate_wordpress_salts)
        awk -v salts="$salts" '
            BEGIN {replaced=0}
            /define\(.*_KEY.*\)|define\(.*_SALT.*\)/ {
                if (!replaced) {
                    print salts
                    replaced=1
                }
                next
            }
            {print}
        ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    fi

    # Add loopback request fix
    add_loopback_fix /var/www/html/wp-config.php

    # If not stateless, copy to /content for persistence
    if [ ! -f /content/wp-config.php ] && [ "${IS_STATELESS:-false}" != "true" ]; then
        log_info "Creating /content directory for persistence"
        mkdir -p /content
        log_info "Copying wp-config.php to /content for persistence"
        cp /var/www/html/wp-config.php /content/wp-config.php
        chown www-data:www-data /content/wp-config.php
    fi

    # If wp-config.php exists in /content, symlink it to /var/www/html
    if [ -f /content/wp-config.php ] && [ "${IS_STATELESS:-false}" != "true" ]; then
        log_info "Symlinking wp-config.php from /content"
        ln -sf /content/wp-config.php /var/www/html/wp-config.php
        chown www-data:www-data /var/www/html/wp-config.php
    fi

    log_info "WordPress configuration initialization completed"
fi