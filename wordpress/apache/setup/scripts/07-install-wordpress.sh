#!/bin/bash
set -e

echo "=== Installing WordPress ==="

mkdir -p /var/www/html
cd /var/www/html

# Download and extract WordPress
wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz
tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz
rm wordpress-${WORDPRESS_VERSION}.tar.gz
mv wordpress/* .
rm -rf wordpress

# Set permissions
chown -R www-data:www-data /var/www/html

echo "=== WordPress installed successfully ==="
