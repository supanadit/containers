#!/bin/bash
set -e

echo "=== Installing PHP extensions ==="

# Set the PHP source directory
PHP_SRC_DIR="/tmp/downloads/php/php-${PHP_VERSION}"

# Install PHP EXIF extension
echo "Installing EXIF extension..."
cd ${PHP_SRC_DIR}/ext/exif
/usr/local/bin/phpize
./configure --with-php-config=/usr/local/bin/php-config
make
make install
echo "extension=exif.so" >> /usr/local/lib/php.ini

# Install and enable PHP OPCache extension
echo "Installing OPCache extension..."
cd ${PHP_SRC_DIR}/ext/opcache
/usr/local/bin/phpize
./configure --with-php-config=/usr/local/bin/php-config
make
make install
echo "zend_extension=opcache.so" >> /usr/local/lib/php.ini

# Download and install PHP Redis extension
echo "Installing Redis extension..."
cd /tmp
git clone https://github.com/phpredis/phpredis.git /tmp/phpredis
cd /tmp/phpredis
/usr/local/bin/phpize
./configure --with-php-config=/usr/local/bin/php-config
make
make install
echo "extension=redis.so" >> /usr/local/lib/php.ini
rm -rf /tmp/phpredis

# Download and install PHP Memcached extension
echo "Installing Memcached extension..."
cd /tmp
git clone https://github.com/php-memcached-dev/php-memcached.git /tmp/php-memcached
cd /tmp/php-memcached
/usr/local/bin/phpize
./configure --with-php-config=/usr/local/bin/php-config
make
make install
echo "extension=memcached.so" >> /usr/local/lib/php.ini
rm -rf /tmp/php-memcached

# Now clean up the PHP source directory
echo "Cleaning up PHP source..."
cd /tmp
rm -rf /tmp/downloads/php/php-${PHP_VERSION}

echo "=== PHP extensions installed successfully ==="
