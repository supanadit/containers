#!/bin/bash
set -e

echo "=== Configure Grafana Loki Template ==="

cd /tmp/downloads

curl -LO "https://raw.githubusercontent.com/grafana/loki/v${GRAFANA_LOKI_VERSION}/cmd/loki/loki-local-config.yaml"

mkdir -p /etc/loki
mv loki-local-config.yaml /etc/loki/loki.yaml

echo "=== Configuring Grafana Loki successfully ==="