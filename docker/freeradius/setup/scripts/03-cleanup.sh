#!/bin/bash
set -e

echo "=== Installing runtime dependencies ==="

# Install runtime libraries needed for FreeRADIUS
apt-get install -y \
    libssl3 \
    libtalloc2 \
    libpcap0.8 \
    libmariadb3 \
    libpq5 \
    libldap-2.5-0 \
    libsasl2-2 \
    libreadline8 \
    libidn2-0 \
    libcurl4 \
    libjson-c5 \
    libkrb5-3 \
    libwbclient0 \
    libpam0g \
    python3

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove build-time dependencies
apt-get remove -y \
    build-essential \
    autoconf \
    libtool \
    libssl-dev \
    libtalloc-dev \
    libpcap-dev \
    libmariadb-dev \
    libpq-dev \
    libldap2-dev \
    libsasl2-dev \
    libreadline-dev \
    libidn2-dev \
    libcurl4-openssl-dev \
    libjson-c-dev \
    libkrb5-dev \
    libwbclient-dev \
    libpam0g-dev \
    python3-dev

# Remove temporary download directories
rm -rf /tmp/downloads /temp

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Remove unnecessary packages
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
