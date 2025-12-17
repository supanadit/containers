#!/bin/bash
set -e

echo "=== Installing Grafana Pyroscope ==="

mkdir /tmp/downloads
cd /tmp/downloads

mkdir -p /usr/share/grafana

curl -LO "https://github.com/grafana/pyroscope/releases/download/v${GRAFANA_PYROSCOPE_VERSION}/pyroscope_${GRAFANA_PYROSCOPE_VERSION}_linux_amd64.tar.gz"

tar -xzf pyroscope_${GRAFANA_PYROSCOPE_VERSION}_linux_amd64.tar.gz
mv pyroscope /usr/share/grafana/pyroscope

echo "=== Grafana Pyroscope installed successfully ==="