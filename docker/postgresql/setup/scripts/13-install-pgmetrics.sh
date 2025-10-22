#!/bin/bash
set -e

echo "=== Installing pgmetrics from source ==="

cd /temp

wget -O pgmetrics_${PGMETRICS_VERSION}_linux_amd64.tar.gz https://github.com/rapidloop/pgmetrics/releases/download/v${PGMETRICS_VERSION}/pgmetrics_${PGMETRICS_VERSION}_linux_amd64.tar.gz

tar -xzf pgmetrics_${PGMETRICS_VERSION}_linux_amd64.tar.gz
mv pgmetrics_${PGMETRICS_VERSION}_linux_amd64/pgmetrics /usr/local/bin/pgmetrics

chmod +x /usr/local/bin/pgmetrics

echo "=== pgmetrics installed successfully ==="