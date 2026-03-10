#!/bin/bash
set -e

echo "=== Building and installing APR ==="

mkdir -p /tmp/downloads/apr
cd /tmp/downloads/apr

# Download and extract APR
wget https://archive.apache.org/dist/apr/apr-${APR_VERSION}.tar.gz
tar -xzf apr-${APR_VERSION}.tar.gz
rm apr-${APR_VERSION}.tar.gz

cd apr-${APR_VERSION}
./configure --prefix=/usr/local/apr
make -j$(nproc)
make install
cd ..

# Download and extract APR-Util
wget https://archive.apache.org/dist/apr/apr-util-${APR_UTIL_VERSION}.tar.gz
tar -xzf apr-util-${APR_UTIL_VERSION}.tar.gz
rm apr-util-${APR_UTIL_VERSION}.tar.gz

cd apr-util-${APR_UTIL_VERSION}
./configure --prefix=/usr/local/apr --with-apr=/usr/local/apr --with-crypto --with-openssl
make -j$(nproc)
make install

cd /
rm -rf /tmp/downloads/apr

echo "=== APR installed successfully ==="
