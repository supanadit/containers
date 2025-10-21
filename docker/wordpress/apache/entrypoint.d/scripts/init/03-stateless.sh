#!/bin/bash
# 03-stateless.sh - Configure stateless mode

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring stateless mode"

# If IS_STATELESS only symlink wp-content/uploads
if [ "${IS_STATELESS:-false}" = "true" ]; then
    log_info "Configuring stateless mode - uploads only"

    # Create directory uploads if it doesn't exist in /content
    if [ ! -d /content/wp-content/uploads ]; then
        log_info "Creating /content/wp-content/uploads directory"
        mkdir -p /content/wp-content/uploads
        chown www-data:www-data /content/wp-content/uploads
        chmod -R 775 /content/wp-content/uploads
    fi

    ln -s /content/wp-content/uploads /var/www/html/wp-content
else
    log_info "Configuring stateful mode - full wp-content persistence"

    # Create symlink for all wp-content directories but first copy to /content
    if [ ! -d /content/wp-content ]; then
        log_info "Creating /content/wp-content directory"
        mkdir -p /content/wp-content
        log_info "Initializing wp-content in /content"
        cp -r /var/www/html/wp-content/* /content/wp-content/
    fi

    if [ -d /var/www/html/wp-content ]; then
        rm -rf /var/www/html/wp-content
        ln -s /content/wp-content /var/www/html
        chown -R www-data:www-data /var/www/html/wp-content
    fi
fi

log_info "Stateless configuration completed"