#!/bin/bash
set -e

echo "=== Installing Freeradius ==="

mkdir -p /tmp/freeradius-build

cd /tmp/freeradius-build
BRANCH="release_${FREERADIUS_VERSION//./_}"
git clone -b ${BRANCH} --depth 1 https://github.com/FreeRADIUS/freeradius-server.git

cd freeradius-server

./configure --prefix=/usr/local/freeradius \
    --with-openssl \
    --with-pcre \
    --enable-developer \
    --with-experimental-modules

make
make install

cd /
rm -rf /tmp/freeradius-build

echo "=== Creating freerad user and group ==="
groupadd -r freerad || true
useradd -r -g freerad -s /bin/false -d /usr/local/freeradius freerad || true

echo "=== Setting up FreeRADIUS directories ==="
mkdir -p /usr/local/freeradius/etc/raddb/sites-available
mkdir -p /usr/local/freeradius/etc/raddb/sites-enabled
mkdir -p /usr/local/freeradius/etc/raddb/mods-available
mkdir -p /usr/local/freeradius/etc/raddb/mods-enabled
mkdir -p /usr/local/freeradius/etc/raddb/certs
mkdir -p /usr/local/freeradius/log
mkdir -p /usr/local/freeradius/run
mkdir -p /usr/local/freeradius/var/log
mkdir -p /usr/local/freeradius/var/run

chown -R freerad:freerad /usr/local/freeradius/log /usr/local/freeradius/run /usr/local/freeradius/var

echo "=== Enabling default site ==="
cd /usr/local/freeradius/etc/raddb/sites-enabled
ln -sf ../sites-available/default default 2>/dev/null || true
ln -sf ../sites-available/inner-tunnel inner-tunnel 2>/dev/null || true

echo "=== FreeRADIUS installed successfully ==="
