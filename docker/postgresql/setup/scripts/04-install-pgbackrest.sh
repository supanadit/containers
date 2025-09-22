#!/bin/bash
set -e

echo "=== Building and installing pgbackrest ==="


cd /temp
mkdir -p /temp/build
wget -q -O - https://github.com/pgbackrest/pgbackrest/archive/release/${PGBACKREST_VERSION}.tar.gz | tar zx -C /temp/build

meson setup /temp/build/pgbackrest /temp/build/pgbackrest-release-${PGBACKREST_VERSION}
ninja -C /temp/build/pgbackrest

cp /temp/build/pgbackrest/src/pgbackrest /usr/bin
chmod 755 /usr/bin/pgbackrest

touch /etc/pgbackrest.conf
chmod 640 /etc/pgbackrest.conf
chown postgres:postgres /etc/pgbackrest.conf

mkdir -p -m 770 /var/log/pgbackrest
chown postgres:postgres /var/log/pgbackrest

echo "=== pgbackrest installed successfully ==="
