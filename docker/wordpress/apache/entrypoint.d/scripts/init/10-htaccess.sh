#!/bin/bash
# 10-htaccess.sh - Configure .htaccess file

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring .htaccess"

if ! grep -q "# BEGIN WordPress" /var/www/html/.htaccess 2>/dev/null; then
    log_info "Adding WordPress rewrite rules to .htaccess"
    cat <<'EOF' >> /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
fi

# If IS_PROTECT_XMLRPC is true, block xmlrpc.php requests
if [ "${IS_PROTECT_XMLRPC:-false}" = "true" ]; then
    log_info "Protecting xmlrpc.php"
    if ! grep -q "deny from all" /var/www/html/.htaccess; then
        echo "<Files xmlrpc.php>" >> /var/www/html/.htaccess
        echo "    order deny,allow" >> /var/www/html/.htaccess
        echo "    deny from all" >> /var/www/html/.htaccess
        echo "</Files>" >> /var/www/html/.htaccess
    fi
fi

if [ "${IS_PROTECT_WPCONFIG:-false}" = "true" ]; then
    log_info "Protecting wp-config.php"
    # If wp-config.php is not blocked, add rules to block it
    if ! grep -q "<Files wp-config.php>" /var/www/html/.htaccess; then
        echo "<Files wp-config.php>" >> /var/www/html/.htaccess
        echo "    Require all denied" >> /var/www/html/.htaccess
        echo "</Files>" >> /var/www/html/.htaccess
    fi
fi

# If .htaccess exists, chown and set permissions
if [ -f /var/www/html/.htaccess ]; then
    chown www-data:www-data /var/www/html/.htaccess
    # w3-total-cache need write access to .htaccess
    chmod 775 /var/www/html/.htaccess
fi

log_info ".htaccess configuration completed"