#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove remaining temporary download directories
rm -rf /temp

echo "=== Removing development packages ==="
apt-get remove --purge -y \
    build-essential \
    gcc \
    autoconf \
    automake \
    meson \
    git \
    curl \
    wget \
    pkg-config \
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    liblz4-dev \
    libzstd-dev \
    libbz2-dev \
    libz-dev \
    libyaml-dev \
    libssh2-1-dev \
    libcurl4-openssl-dev \
    libffi-dev \
    libpq-dev \
    python3-distutils \
    protobuf-c-compiler \
    libprotobuf-c-dev

# Install runtime libraries that are needed but development packages were removed
apt-get install -y --no-install-recommends \
    libssl3 \
    libxml2 \
    liblz4-1 \
    libzstd1 \
    libbz2-1.0 \
    zlib1g \
    libyaml-0-2 \
    libssh2-1 \
    libcurl4 \
    libffi8 \
    libreadline8

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Remove unnecessary packages
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
