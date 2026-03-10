#!/bin/bash
set -e

echo "=== Cleaning up ==="

# Remove package lists
rm -rf /var/lib/apt/lists/*

# Remove temporary files
rm -rf /tmp/*

echo "=== Cleanup completed ==="