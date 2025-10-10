#!/bin/bash
set -e

echo "=== Building and installing PostgreSQL ==="

mkdir /temp

mkdir -p /temp/sources
cd /temp/sources

curl -O https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz

tar -xzf postgresql-${POSTGRESQL_VERSION}.tar.gz

cd /temp/sources/postgresql-${POSTGRESQL_VERSION}

# Configure PostgreSQL with all needed options
./configure --prefix=/usr/local/pgsql \
    --with-openssl \
    --with-libxml \
    --with-uuid=ossp

# Build and install PostgreSQL core
make && make install

# Build and install contrib modules (includes uuid-ossp and other extensions)
echo "=== Building contrib modules ==="
cd contrib
make && make install

# Verify that uuid-ossp extension files are installed
echo "=== Verifying uuid-ossp extension installation ==="
if [ -f "/usr/local/pgsql/share/extension/uuid-ossp.control" ]; then
    echo "uuid-ossp extension installed successfully"
else
    echo "ERROR: uuid-ossp extension not found!"
    exit 1
fi

mkdir -p /usr/local/pgsql/data

useradd -m postgres
chown -R postgres:postgres /usr/local/pgsql
chmod 700 /usr/local/pgsql/data

echo "=== PostgreSQL installed successfully ==="
