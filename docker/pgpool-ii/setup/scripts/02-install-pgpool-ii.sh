#!/bin/bash
set -e

echo "=== Building and installing PgPool-II ==="

mkdir /temp

mkdir -p /temp/sources
cd /temp/sources

# https://github.com/pgpool/pgpool2.git
# Tag prefix is V4_6_3 for version 4.6.3
git clone --branch V${PGPOOLII_VERSION//./_} --depth 1 https://github.com/pgpool/pgpool2.git && cd pgpool2

# Install pgpool-II
./autogen.sh
./configure --prefix=/usr/local/pgpool
make
make install

echo "=== PgPool-II installed successfully ==="
