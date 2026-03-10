#!/bin/bash
set -e

echo "=== Installing daloRADIUS ${DALORADIUS_VERSION} ==="

mkdir -p /var/www/html
mkdir -p /tmp/downloads/daloradius
cd /tmp/downloads/daloradius

# Download daloRADIUS from GitHub
if [ "$DALORADIUS_VERSION" = "master" ] || [ "$DALORADIUS_VERSION" = "1.3" ]; then
    wget -q https://github.com/lirantal/daloradius/archive/refs/heads/master.zip -O daloradius.zip
else
    wget -q https://github.com/lirantal/daloradius/archive/refs/tags/${DALORADIUS_VERSION}.zip -O daloradius.zip
fi

unzip -q daloradius.zip
rm daloradius.zip

# Find the extracted directory reliably
EXTRACTED_DIR=$(ls -d daloradius-*/ 2>/dev/null | head -n 1)
if [ -z "$EXTRACTED_DIR" ]; then
    echo "ERROR: Could not find extracted daloRADIUS directory"
    exit 1
fi

# Move to web root
mv "$EXTRACTED_DIR" /var/www/html/daloradius

# Create symbolic link to root for easier access
cd /var/www/html
ln -sf daloradius html

# Set proper permissions
chown -R www-data:www-data /var/www/html/daloradius
chmod -R 755 /var/www/html/daloradius

# Create daloradius log file
touch /tmp/daloradius.log
chown www-data:www-data /tmp/daloradius.log

# Create Apache log directory for daloRADIUS
mkdir -p /var/log/apache2/daloradius
chown -R www-data:www-data /var/log/apache2/daloradius

cd /
rm -rf /tmp/downloads/daloradius

echo "=== daloRADIUS installed successfully ==="
