#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    unzip

update-ca-certificates

echo "=== Dependencies installed successfully ==="
