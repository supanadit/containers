#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

rm -rf /tmp/downloads

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
