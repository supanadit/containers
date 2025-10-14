#!/bin/bash
set -e

echo "=========================================="
echo "Starting Grafana Mimir setup..."
echo "=========================================="

SCRIPT_DIR="/opt/setup/scripts"

chmod +x ${SCRIPT_DIR}/*.sh

${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-grafana-mimir.sh
${SCRIPT_DIR}/03-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
