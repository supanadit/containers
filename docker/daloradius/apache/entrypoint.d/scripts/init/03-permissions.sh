#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Setting proper permissions"

# Set ownership
chown -R www-data:www-data /var/www/html/daloradius

# Set directory permissions
find /var/www/html/daloradius -type d -exec chmod 755 {} \;

# Set file permissions
find /var/www/html/daloradius -type f -exec chmod 644 {} \;

# Ensure specific files have correct permissions
chmod 640 /var/www/html/daloradius/library/daloradius.conf.php 2>/dev/null || true
chmod 644 /var/www/html/daloradius/library/daloradius.conf.php 2>/dev/null || true

# Create required directories
mkdir -p /var/log/apache2/daloradius
chown -R www-data:www-data /var/log/apache2/daloradius

# Ensure log files exist
touch /tmp/daloradius.log
chown www-data:www-data /tmp/daloradius.log

log_info "Permissions set successfully"
