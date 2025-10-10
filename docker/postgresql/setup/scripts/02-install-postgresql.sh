#!/bin/bash
set -e

echo "=== Building and installing PostgreSQL ==="

mkdir /temp

mkdir -p /temp/sources
cd /temp/sources

curl -O https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz

tar -xzf postgresql-${POSTGRESQL_VERSION}.tar.gz

cd /temp/sources/postgresql-${POSTGRESQL_VERSION}

# Install PostgreSQL
./configure --prefix=/usr/local/pgsql && make && make install

# Install contrib modules (includes uuid-ossp and other extensions)
cd contrib
make && make install

mkdir -p /usr/local/pgsql/data

useradd -m postgres
chown -R postgres:postgres /usr/local/pgsql
chmod 700 /usr/local/pgsql/data

echo "=== PostgreSQL installed successfully ==="
