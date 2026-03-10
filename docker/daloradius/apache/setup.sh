#!/bin/bash
set -e

echo "=========================================="
echo "Starting daloRADIUS + Apache + PHP Setup"
echo "=========================================="

# Set script directory
SCRIPT_DIR="/opt/setup/scripts"

# Make all scripts executable
chmod +x ${SCRIPT_DIR}/*.sh

# Execute setup scripts in order
${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-apr.sh
${SCRIPT_DIR}/03-install-apache.sh
${SCRIPT_DIR}/04-install-php.sh
${SCRIPT_DIR}/05-install-pear.sh
${SCRIPT_DIR}/06-install-daloradius.sh
${SCRIPT_DIR}/07-configure-apache.sh
${SCRIPT_DIR}/08-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
