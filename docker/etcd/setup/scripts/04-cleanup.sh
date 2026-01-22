#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Cleanup Go installation
rm -rf /usr/local/go
rm -rf /go

# Remove remaining temporary download directories
rm -rf /temp

echo "=== Removing development packages ==="
apt-get remove --purge -y \
    git \
    curl \
    wget \
    make \
    build-essential

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Remove unnecessary packages
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
