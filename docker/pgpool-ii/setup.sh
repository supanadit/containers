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
${SCRIPT_DIR}/02-install-pgpool-ii.sh
${SCRIPT_DIR}/99-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
