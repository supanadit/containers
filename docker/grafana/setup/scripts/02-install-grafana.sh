#!/bin/bash
set -e

echo "=== Installing Grafana ==="

mkdir /tmp/downloads
cd /tmp/downloads

mkdir -p /usr/share/grafana

# Download Grafana
if [ "$GRAFANA_EDITION" = "oss" ]; then
    curl -LO "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"

    # Extract the downloaded tarball
    tar -xzf "grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz" --strip-components=1 -C /usr/share/grafana
    rm "grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"
else
    curl -LO "https://dl.grafana.com/enterprise/release/grafana-${GRAFANA_EDITION}-${GRAFANA_VERSION}.linux-amd64.tar.gz"
    tar -xzf "grafana-${GRAFANA_EDITION}-${GRAFANA_VERSION}.linux-amd64.tar.gz" --strip-components=1 -C /usr/share/grafana
    rm "grafana-${GRAFANA_EDITION}-${GRAFANA_VERSION}.linux-amd64.tar.gz"
fi

# Create necessary directories
mkdir -p /etc/grafana/provisioning
mkdir -p /var/log/grafana
mkdir -p /var/lib/grafana/plugins

# Add chmod +x to the grafana binary
chmod +x /usr/share/grafana/bin/grafana-server