#!/bin/bash
set -e

echo "=== Configure Grafana Loki Template ==="

cd /tmp/downloads

curl -LO "https://raw.githubusercontent.com/grafana/loki/v${GRAFANA_LOKI_VERSION}/cmd/loki/loki-docker-config.yaml"

mkdir -p /etc/loki
mv loki-docker-config.yaml /etc/loki/loki-sample.yaml

echo "=== Configuring Grafana Loki successfully ==="