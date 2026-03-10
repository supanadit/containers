#!/bin/bash
# 08-apache-status.sh - Configure Apache server status

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring Apache server status"

APACHE_STATUS=${APACHE_STATUS:-false}
APACHE_STATUS_PUBLIC=${APACHE_STATUS_PUBLIC:-false}

if [ "$APACHE_STATUS" = "true" ]; then
    log_info "Enabling Apache server status"

    # Enable mod_status
    if ! grep -q "^LoadModule status_module" /usr/local/apache2/conf/httpd.conf; then
        echo "LoadModule status_module modules/mod_status.so" >> /usr/local/apache2/conf/httpd.conf
    fi

    # Create the status config file
    log_info "Creating httpd-status.conf"
    cat <<'EOF' > /usr/local/apache2/conf/extra/httpd-status.conf
ExtendedStatus On
<Location /server-status>
    SetHandler server-status
    Require local
</Location>
EOF

    # If APACHE_STATUS_PUBLIC is true, allow public access to server-status
    if [ "$APACHE_STATUS_PUBLIC" = "true" ]; then
        log_info "Making server status publicly accessible"
        sed -i 's/Require local/Require all granted/' /usr/local/apache2/conf/extra/httpd-status.conf
    fi

    # Include the status config file - ensure it's only added once
    if ! grep -q "^Include conf/extra/httpd-status.conf" /usr/local/apache2/conf/httpd.conf; then
        log_info "Adding Include directive for httpd-status.conf"
        echo "Include conf/extra/httpd-status.conf" >> /usr/local/apache2/conf/httpd.conf
    fi

    chmod 644 /usr/local/apache2/conf/extra/httpd-status.conf
    
    log_info "Apache server status enabled - endpoint: /server-status"
else
    log_info "Apache server status disabled"
fi

log_info "Apache server status configuration completed"