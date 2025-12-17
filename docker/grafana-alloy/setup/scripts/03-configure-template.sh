#!/bin/bash
set -e

echo "=== Configure Grafana Alloy Template ==="

cd /tmp/downloads

curl -LO "https://raw.githubusercontent.com/grafana/alloy/v${GRAFANA_LOKI_VERSION}/example-config.alloy"

mkdir -p /etc/alloy
mv example-config.alloy /etc/alloy/config.alloy

echo "=== Configuring Grafana Alloy successfully ==="