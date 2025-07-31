#!/bin/bash
set -e

echo "=== Building and installing Apache HTTP Server ==="

cd /tmp

# Download and extract Apache
wget https://downloads.apache.org/httpd/httpd-${APACHE_VERSION}.tar.gz
tar -xzf httpd-${APACHE_VERSION}.tar.gz
rm httpd-${APACHE_VERSION}.tar.gz

# Install Apache
cd httpd-${APACHE_VERSION}
./configure \
    --with-apr=/usr/local/apr \
    --with-apr-util=/usr/local/apr/bin/apu-1-config \
    --enable-so \
    --enable-ssl \
    --enable-mpms-shared=all
make
make install
make clean
cd ..

# Cleanup
rm -rf httpd-${APACHE_VERSION}

echo "=== Apache HTTP Server installed successfully ==="
