#!/bin/bash
set -e

PGBOUNCER_VERSION="1.24.1"
PGBOUNCER_TAG="pgbouncer_1_24_1"

echo "=== Building and installing PgBouncer ==="

mkdir -p /temp/sources
cd /temp/sources

# Download PgBouncer source
wget https://github.com/pgbouncer/pgbouncer/releases/download/$PGBOUNCER_TAG/pgbouncer-$PGBOUNCER_VERSION.tar.gz

mkdir -p /var/log/pgbouncer

tar -xzf pgbouncer-$PGBOUNCER_VERSION.tar.gz

mkdir -p /var/run/pgbouncer

cd pgbouncer-$PGBOUNCER_VERSION

# Configure and build
./configure --prefix=/usr/local/pgbouncer \
    --with-libevent=/usr/lib \
    --with-cares=/usr/lib

make
make install

# Create necessary directories
mkdir -p /var/log/pgbouncer
mkdir -p /var/run/pgbouncer
mkdir -p /etc/pgbouncer

# Set proper ownership
chown -R postgres:postgres /etc/pgbouncer

# Set permissions
chown -R postgres:postgres /var/log/pgbouncer
chown -R postgres:postgres /var/run/pgbouncer
chown -R postgres:postgres /etc/pgbouncer

echo "=== PgBouncer installed successfully ==="