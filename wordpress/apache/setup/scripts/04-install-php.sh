#!/bin/bash
set -e

echo "=== Building and installing PHP ==="

mkdir -p /tmp/downloads/php
cd /tmp/downloads/php

# Download and extract PHP
wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz
tar -xzf php-${PHP_VERSION}.tar.gz
rm php-${PHP_VERSION}.tar.gz

# Install and compile PHP
cd php-${PHP_VERSION}
./configure \
    --with-apxs2=/usr/local/apache2/bin/apxs \
    --enable-mbstring \
    --with-curl \
    --with-openssl \
    --with-pdo-mysql \
    --with-mysqli \
    --with-zlib
make -j$(nproc)
make install
# Don't run make clean yet - we need the source for extensions

# Setup PHP configuration
cp php.ini-production /usr/local/lib/php.ini
sed -i 's/;date.timezone =/date.timezone = UTC/' /usr/local/lib/php.ini

echo "=== PHP installed successfully ==="
