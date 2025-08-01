#!/bin/bash
set -e

echo "=== Installing WordPress ==="

cd /var/www/html

# Download and extract WordPress
wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz
tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz
rm wordpress-${WORDPRESS_VERSION}.tar.gz
mv wordpress/* .
rm -rf wordpress

echo "=== WordPress installed successfully ==="
