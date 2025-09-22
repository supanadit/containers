#!/bin/bash
set -e

echo "=========================================="
echo "Starting PostgreSQL Setup"
echo "=========================================="

# Set script directory
SCRIPT_DIR="/opt/setup/scripts"

# Make all scripts executable
chmod +x ${SCRIPT_DIR}/*.sh

# Execute setup scripts in order
${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-postgresql.sh
${SCRIPT_DIR}/03-install-python.sh
${SCRIPT_DIR}/04-install-pgbackrest.sh
${SCRIPT_DIR}/05-install-citus.sh
${SCRIPT_DIR}/06-install-pgstatmonitor.sh
${SCRIPT_DIR}/07-install-decoderbufs.sh
${SCRIPT_DIR}/08-install-patroni.sh
${SCRIPT_DIR}/09-cleanup.sh

echo "=========================================="
echo "Installing modular entrypoint scripts"
echo "=========================================="

# Create entrypoint.d directory structure
mkdir -p /opt/container/entrypoint.d/scripts/utils
mkdir -p /opt/container/entrypoint.d/scripts/init
mkdir -p /opt/container/entrypoint.d/scripts/runtime
mkdir -p /opt/container/entrypoint.d/scripts/test/unit
mkdir -p /opt/container/entrypoint.d/scripts/test/integration

# Copy entrypoint scripts (these would be copied during Docker build)
# Note: In a real implementation, these files would be copied from the build context
echo "Entrypoint scripts would be copied here during Docker build"

# Make scripts executable
chmod +x /opt/container/entrypoint.d/entrypoint.sh 2>/dev/null || true
find /opt/container/entrypoint.d/scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
