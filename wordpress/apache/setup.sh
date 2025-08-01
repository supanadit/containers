#!/bin/bash
set -e

echo "=========================================="
echo "Starting WordPress + Apache + PHP Setup"
echo "=========================================="

# Set script directory
SCRIPT_DIR="/opt/setup/scripts"

# Make all scripts executable
chmod +x ${SCRIPT_DIR}/*.sh

# Execute setup scripts in order
${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-apr.sh
${SCRIPT_DIR}/03-install-apache.sh
${SCRIPT_DIR}/04-install-apache-exporter.sh
${SCRIPT_DIR}/05-install-php.sh
${SCRIPT_DIR}/06-install-php-extensions.sh
${SCRIPT_DIR}/07-install-wordpress.sh
${SCRIPT_DIR}/08-configure-apache.sh
${SCRIPT_DIR}/09-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
