#!/bin/bash
# startup.sh - Start the WordPress application

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Starting WordPress application"

# Final permission check and fix before starting Apache
log_info "Performing final permission check"

# Ensure wp-content directories have correct permissions
if [ -d "/var/www/html/wp-content" ]; then
    # Create missing directories
    mkdir -p /var/www/html/wp-content/uploads
    mkdir -p /var/www/html/wp-content/fonts

    # Set directory permissions
    find /var/www/html/wp-content -type d -exec chmod 775 {} \; 2>/dev/null || true
    find /var/www/html/wp-content -type f -exec chmod 664 {} \; 2>/dev/null || true

    # Set ownership
    chown -R www-data:www-data /var/www/html/wp-content 2>/dev/null || true

    log_info "Final permissions applied to wp-content"
fi

# Execute the main command (typically Apache)
exec "$@"