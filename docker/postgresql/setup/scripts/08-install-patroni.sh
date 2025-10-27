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

# Add the PostgreSQL lib path to ldconfig for runtime (moved up to ensure libraries are linked before installing psycopg2-binary)
echo "/usr/local/pgsql/lib" > /etc/ld.so.conf.d/postgresql.conf
ldconfig

cd /temp
git clone -b ${PATRONI_VERSION} --depth 1 https://github.com/patroni/patroni.git

cd /temp/patroni

# Selected patroni version does not support latest psycop-c
# In 26 October 2025, they release psycopg-c 3.2.12 at https://pypi.org/project/psycopg-c/3.2.12/
# We should stick with 3.2.11 until patroni support it
pip install "psycopg[c]==3.2.11"
pip install cdiff

pip install -r requirements.txt
pip install .[etcd]

echo "=== Patroni installed successfully ==="