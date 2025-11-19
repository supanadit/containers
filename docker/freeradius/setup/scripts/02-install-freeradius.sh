#!/bin/bash
set -e

echo "=== Installing Freeradius ==="

mkdir /temp

cd /temp
git clone -b ${FREERADIUS_VERSION} https://github.com/FreeRADIUS/freeradius-server.git --depth 1
cd freeradius-server

# Configure and build
./configure --prefix=/usr/local/freeradius \
    --with-openssl \
    --with-pcre \
    --enable-developer

make
make install

echo "=== Freeradius installed successfully ==="

