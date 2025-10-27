#!/bin/bash
set -e

echo "=== Installing pg_repack from source ==="

if [ -z "${PGREPACK_VERSION}" ]; then
    echo "PGREPACK_VERSION is not set. Please set the build arg PGREPACK_VERSION in the Dockerfile or environment." >&2
    exit 1
fi

mkdir -p /temp/sources
cd /temp/sources

git clone --branch ver_${PGREPACK_VERSION} https://github.com/reorg/pg_repack.git

cd pg_repack

# Build and install pg_repack using pg_config from the built PostgreSQL
make PG_CONFIG=/usr/local/pgsql/bin/pg_config USE_PGXS=1
make PG_CONFIG=/usr/local/pgsql/bin/pg_config USE_PGXS=1 install

# Verify installation
if [ -f "/usr/local/pgsql/share/extension/pg_repack.control" ] || [ -f "/usr/local/pgsql/lib/postgresql/pg_repack.so" ]; then
    echo "pg_repack installed successfully"
else
    echo "ERROR: pg_repack extension not found after install" >&2
    exit 1
fi

echo "=== pg_repack installation completed ==="
