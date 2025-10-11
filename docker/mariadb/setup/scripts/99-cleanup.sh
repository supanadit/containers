#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove remaining temporary download directories
rm -rf /temp

echo "=== Removing development packages ==="
apt-get remove --purge -y \
    build-essential \
    cmake \
    git \
    wget \
    pkg-config \
    libssl-dev \
    libncurses-dev \
    libreadline-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    liblzma-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libpcre2-dev \
    libjemalloc-dev \
    libsnappy-dev \
    bison \
    gnutls-dev \
    libgnutls28-dev \
    libpam0g-dev \
    libaio-dev \
    libnuma-dev \
    libsystemd-dev \
    libkrb5-dev

# Install runtime libraries that are needed but development packages were removed
apt-get install -y --no-install-recommends \
    curl \
    libssl3 \
    libncurses6 \
    libreadline8 \
    zlib1g \
    libbz2-1.0 \
    liblz4-1 \
    libzstd1 \
    liblzma5 \
    libxml2 \
    libcurl4 \
    libpcre2-8-0 \
    libjemalloc2 \
    libsnappy1v5 \
    libgnutls30 \
    libpam0g \
    libaio1 \
    libnuma1 \
    libsystemd0 \
    libgssapi-krb5-2 \
    libkrb5-3 \
    procps \
    gosu

# Remove unnecessary packages first
apt-get autoremove --purge -y

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Final autoclean
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
