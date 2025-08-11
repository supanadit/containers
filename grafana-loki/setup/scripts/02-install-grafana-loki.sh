#!/bin/bash
set -e

echo "=== Installing Grafana Loki ==="

mkdir /tmp/downloads
cd /tmp/downloads

mkdir -p /usr/share/grafana

curl -LO "https://github.com/grafana/loki/releases/download/v${GRAFANA_LOKI_VERSION}/loki-linux-amd64.zip"

unzip loki-linux-amd64.zip
mv loki-linux-amd64 /usr/share/grafana/loki

echo "=== Grafana Loki installed successfully ==="