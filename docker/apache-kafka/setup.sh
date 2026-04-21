#!/bin/bash
set -e

echo "=========================================="
echo "Starting Kafka Setup"
echo "=========================================="

# Export build args as environment variables for child scripts
export KAFKA_VERSION=${KAFKA_VERSION:-3.9.1}
export JAVA_VERSION=${JAVA_VERSION:-21}

echo "Build configuration:"
echo "  KAFKA_VERSION: ${KAFKA_VERSION}"
echo "  JAVA_VERSION: ${JAVA_VERSION}"

# Set script directory
SCRIPT_DIR="/opt/setup/scripts"

# Make all scripts executable
chmod +x ${SCRIPT_DIR}/*.sh

# Execute setup scripts in order
${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-java.sh
${SCRIPT_DIR}/03-install-kafka.sh
${SCRIPT_DIR}/99-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
