#!/bin/bash
set -e

echo "=== Installing Grafana Alloy ==="

mkdir /tmp/downloads
cd /tmp/downloads

mkdir -p /usr/share/grafana

curl -LO "https://github.com/grafana/alloy/releases/download/v${GRAFANA_LOKI_VERSION}/alloy-linux-amd64.zip"

unzip alloy-linux-amd64.zip
mv alloy-linux-amd64 /usr/share/grafana/alloy

echo "=== Grafana Alloy installed successfully ==="