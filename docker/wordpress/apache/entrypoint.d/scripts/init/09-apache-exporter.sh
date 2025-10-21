#!/bin/bash
# 09-apache-exporter.sh - Configure Apache exporter

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring Apache exporter"

APACHE_EXPORTER=${APACHE_EXPORTER:-false} # default to false if not set

# Start Apache Exporter if enabled
if [ "$APACHE_EXPORTER" = "true" ] && [ "$APACHE_STATUS" = "true" ]; then
    log_info "Starting Apache exporter"

    # Load info module using AWK
    awk '
    BEGIN { found=0 }
    /^LoadModule info_module/ {
        print
        found=1
        next
    }
    /^#LoadModule info_module/ {
        print "LoadModule info_module modules/mod_info.so"
        found=1
        next
    }
    {print}
    END {
        if (!found) print "LoadModule info_module modules/mod_info.so"
    }
    ' /usr/local/apache2/conf/httpd.conf > /usr/local/apache2/conf/httpd.conf.tmp && mv /usr/local/apache2/conf/httpd.conf.tmp /usr/local/apache2/conf/httpd.conf

    # Ensure /server-info is accessible using rewrite conditions in .htaccess
    cat <<'EOF' >> /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteCond %{REQUEST_URI} !^/wp-admin/
RewriteCond %{REQUEST_URI} !^/server-status
RewriteCond %{REQUEST_URI} !^/server-info
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

    /usr/local/bin/apache_exporter --scrape_uri="http://localhost/server-status?auto" &
else
    log_info "Apache exporter disabled"
fi

log_info "Apache exporter configuration completed"