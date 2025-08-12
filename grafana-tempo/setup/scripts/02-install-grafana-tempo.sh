#!/bin/bash
set -e

echo "=== Installing Grafana Tempo ==="

mkdir /tmp/downloads
cd /tmp/downloads

mkdir -p /usr/share/grafana

curl -LO "https://github.com/grafana/tempo/releases/download/v${GRAFANA_TEMPO_VERSION}/tempo_${GRAFANA_TEMPO_VERSION}_linux_amd64.tar.gz"

tar -xzf tempo_${GRAFANA_TEMPO_VERSION}_linux_amd64.tar.gz
mv tempo /usr/share/grafana/tempo

echo "=== Grafana Tempo installed successfully ==="