#!/bin/bash
set -e

echo "=== Building and installing Apache HTTP Server ==="

mkdir -p /tmp/downloads/apache
cd /tmp/downloads/apache

# Download and extract Apache
wget https://downloads.apache.org/httpd/httpd-${APACHE_VERSION}.tar.gz
tar -xzf httpd-${APACHE_VERSION}.tar.gz
rm httpd-${APACHE_VERSION}.tar.gz

cd httpd-${APACHE_VERSION}

# Apply security patches if needed
sed -i 's/#define AP_SERVER_MAJORVERSION_NUMBER 2/#define AP_SERVER_MAJORVERSION_NUMBER 2/' include/ap_mmn.h
sed -i 's/#define AP_SERVER_MINORVERSION_NUMBER 4/#define AP_SERVER_MINORVERSION_NUMBER 66/' include/ap_mmn.h

./configure \
    --with-apr=/usr/local/apr \
    --with-apr-util=/usr/local/apr \
    --enable-so \
    --enable-ssl \
    --enable-rewrite \
    --enable-proxy \
    --enable-mpms-shared=all \
    --with-mpm=prefork
make -j$(nproc)
make install

cd /
rm -rf /tmp/downloads/apache

echo "=== Apache HTTP Server installed successfully ==="
