#!/bin/bash
set -e

echo "=== Installing pgbadger from source ==="

# Install Perl dependencies required by pgbadger
apt-get update -y && apt-get install -y \
    perl \
    libtext-csv-xs-perl \
    libjson-xs-perl \
    libwww-perl \
    libdigest-md5-file-perl

# Create temp directory for source download
cd /temp
mkdir -p /temp/build

# Download latest pgbadger from GitHub
echo "Downloading pgbadger source..."
wget -q -O - https://github.com/darold/pgbadger/archive/master.tar.gz | tar zx -C /temp/build

# Copy pgbadger script to /usr/bin
cp /temp/build/pgbadger-master/pgbadger /usr/bin/pgbadger
chmod 755 /usr/bin/pgbadger

echo "=== pgbadger installed successfully from source ==="