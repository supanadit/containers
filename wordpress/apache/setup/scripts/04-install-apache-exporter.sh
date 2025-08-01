#!/bin/bash
set -e

echo "=== Installing Apache Exporter ==="

cd /tmp

wget https://github.com/Lusitaniae/apache_exporter/releases/download/v${APACHE_EXPORTER_VERSION}/apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64.tar.gz
mv apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64/apache_exporter /usr/local/bin/apache_exporter
chmod +x /usr/local/bin/apache_exporter

rm -rf apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64*
echo "=== Apache Exporter installed ==="