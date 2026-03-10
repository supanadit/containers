#!/bin/bash
set -e

echo "=== Building and installing PHP ${PHP_VERSION} ==="

mkdir -p /tmp/downloads/php
cd /tmp/downloads/php

# Download and extract PHP
wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz
tar -xzf php-${PHP_VERSION}.tar.gz
rm php-${PHP_VERSION}.tar.gz

cd php-${PHP_VERSION}

# Configure PHP with all necessary extensions for daloRADIUS
./configure \
    --with-apxs2=/usr/local/apache2/bin/apxs \
    --with-mysqli \
    --with-pdo-mysql \
    --with-mysql-sock=/run/mysqld/mysqld.sock \
    --enable-mbstring \
    --enable-gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-png \
    --with-curl \
    --with-openssl \
    --with-zlib \
    --with-bz2 \
    --with-zip \
    --enable-intl \
    --enable-snmp \
    --enable-soap \
    --with-icu \
    --enable-bcmath \
    --enable-calendar \
    --enable-exif \
    --enable-ftp \
    --with-pear \
    --with-gettext

make -j$(nproc)
make install

# Setup PHP configuration
cp php.ini-production /usr/local/lib/php.ini
sed -i 's/;date.timezone =/date.timezone = UTC/' /usr/local/lib/php.ini
sed -i 's/;mbstring.func_overload = 0/mbstring.func_overload = 0/' /usr/local/lib/php.ini

cd /
rm -rf /tmp/downloads/php

echo "=== PHP installed successfully ==="
