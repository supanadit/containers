#!/bin/bash
set -e

echo "=== Cleaning up build artifacts ==="

# Unhold packages first
apt-mark unhold libssl-dev libssl1.1 libcurl4-openssl-dev || true

# Remove Bullseye repository to avoid conflicts
rm -f /etc/apt/sources.list.d/bullseye.list

apt-get update || true

# Remove build tools to reduce image size
apt-get remove -y \
    build-essential \
    autoconf \
    libtool \
    bison \
    pkg-config \
    python3-dev \
    libpcre3-dev \
    || true

apt-get autoremove -y
apt-get clean

# Remove apt cache
rm -rf /var/lib/apt/lists/*

# Remove temporary files
rm -rf /tmp/*

echo "=== Cleanup completed ==="
