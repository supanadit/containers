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
${SCRIPT_DIR}/09-install-pgbadger.sh
${SCRIPT_DIR}/10-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
