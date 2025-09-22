#!/bin/bash
set -e

echo "=== Building and installing APR and APR-util ==="

cd /tmp

# Download and extract APR and APR-util
wget https://downloads.apache.org/apr/apr-${APR_VERSION}.tar.gz
tar -xzf apr-${APR_VERSION}.tar.gz
rm apr-${APR_VERSION}.tar.gz

wget https://downloads.apache.org/apr/apr-util-${APR_UTIL_VERSION}.tar.gz
tar -xzf apr-util-${APR_UTIL_VERSION}.tar.gz
rm apr-util-${APR_UTIL_VERSION}.tar.gz

# Install APR
cd apr-${APR_VERSION}
./configure
make
make install
cd ..

# Install APR-util
cd apr-util-${APR_UTIL_VERSION}
./configure --with-apr=/usr/local/apr
make
make install
make clean
cd ..

# Cleanup
rm -rf apr-${APR_VERSION}
rm -rf apr-util-${APR_UTIL_VERSION}

echo "=== APR and APR-util installed successfully ==="
