#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove temporary download directories
rm -rf /tmp/downloads

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Remove unnecessary packages
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
