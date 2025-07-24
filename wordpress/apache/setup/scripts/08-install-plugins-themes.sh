#!/bin/bash
set -e

echo "=== Installing WordPress plugins and themes ==="

# Setup plugin and theme installation scripts
cp /opt/addons/scripts/plugin-install.sh /tmp/plugin-install.sh
cp /opt/addons/scripts/theme-install.sh /tmp/theme-install.sh
chmod +x /tmp/plugin-install.sh
chmod +x /tmp/theme-install.sh

# Install plugins and themes
/tmp/plugin-install.sh /tmp/plugins
/tmp/theme-install.sh /tmp/themes

# Set permissions for WordPress
chown -R www-data:www-data /var/www/html

# Clean up
rm -rf /tmp/plugins /tmp/themes
rm -f /tmp/plugin-install.sh /tmp/theme-install.sh

echo "=== WordPress plugins and themes installed successfully ==="
