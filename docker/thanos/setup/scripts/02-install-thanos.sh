#!/bin/bash
set -e

echo "=== Installing Thanos ==="

mkdir /tmp/downloads
cd /tmp/downloads

# Download Thanos
curl -LO "https://github.com/thanos-io/thanos/releases/download/v${THANOS_VERSION}/thanos-${THANOS_VERSION}.linux-amd64.tar.gz"

# Extract Thanos
tar -xzf "thanos-${THANOS_VERSION}.linux-amd64.tar.gz"

# Move binaries to /usr/local/bin
mv "thanos-${THANOS_VERSION}.linux-amd64/thanos" /usr/local/bin/

# Set permissions
chmod +x /usr/local/bin/thanos

# Create data directory
mkdir -p /opt/thanos/data

echo "=== Thanos installed successfully ==="