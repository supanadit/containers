#!/bin/bash
set -e

echo "=== Cleaning up build artifacts ==="

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

# Clean up temp files
rm -rf /tmp/* 2>/dev/null || true

echo "=== Cleanup completed ==="
