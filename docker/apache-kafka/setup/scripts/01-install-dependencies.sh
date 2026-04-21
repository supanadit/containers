#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y curl wget tar gzip ca-certificates procps gosu

# Create kafka user and group
groupadd -r kafka
useradd -r -g kafka -d /opt/kafka -s /bin/bash kafka

echo "=== Dependencies installed successfully ==="
