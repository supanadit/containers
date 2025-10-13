#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove remaining temporary download directories
rm -rf /temp

echo "=== Removing development packages ==="
apt-get remove --purge -y build-essential

# Remove unnecessary packages first
apt-get autoremove --purge -y

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Final autoclean
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
