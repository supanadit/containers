#!/bin/bash
set -e

echo "=== Installing Prometheus ==="

mkdir /tmp/downloads
cd /tmp/downloads

# Download Prometheus
curl -LO "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

# Extract Prometheus
tar -xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

# Move binaries to /usr/local/bin
mv "prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus" /usr/local/bin/
mv "prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool" /usr/local/bin/

# Set permissions
chmod +x /usr/local/bin/prometheus
chmod +x /usr/local/bin/promtool

# Move configuration files
mkdir -p /etc/prometheus
mv "prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml" /etc/prometheus/