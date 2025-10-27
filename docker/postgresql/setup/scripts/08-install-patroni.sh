#!/bin/bash
set -e

echo "=== Building and installing Patroni ==="

# Make sure PostgreSQL libraries are in the library path
export LD_LIBRARY_PATH="/usr/local/pgsql/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="/usr/local/pgsql/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="/usr/local/pgsql/bin:$PATH"

# Set environment variables for psycopg to find PostgreSQL
export LDFLAGS="-L/usr/local/pgsql/lib"
export CPPFLAGS="-I/usr/local/pgsql/include"

cd /temp
git clone -b ${PATRONI_VERSION} --depth 1 https://github.com/patroni/patroni.git

cd /temp/patroni

pip install "psycopg[c]"
pip install cdiff

pip install -r requirements.txt
pip install .[etcd]

# Add the PostgreSQL lib path to ldconfig for runtime
echo "/usr/local/pgsql/lib" > /etc/ld.so.conf.d/postgresql.conf
ldconfig

echo "=== Patroni installed successfully ==="