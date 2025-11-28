#!/bin/bash
set -e

echo "=== Building and installing Flink ==="

# Use FLINK_VERSION from environment or default
FLINK_VERSION=${FLINK_VERSION:-2.1.1}
SCALA_VERSION=${SCALA_VERSION:-2.12}

echo "Installing Apache Flink ${FLINK_VERSION}"

# Create temp directory
mkdir -p /temp/sources
cd /temp/sources

# Download Flink
FLINK_URL="https://downloads.apache.org/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz"
echo "Downloading from ${FLINK_URL}"
wget "${FLINK_URL}"

# Extract Flink
tar -xzf "flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz"
FLINK_DIR="flink-${FLINK_VERSION}"

# Move to /opt
mv "${FLINK_DIR}" /opt/flink

# Set FLINK_HOME
export FLINK_HOME=/opt/flink
echo "FLINK_HOME=${FLINK_HOME}" >> /etc/environment

# Add to PATH
export PATH="${FLINK_HOME}/bin:${PATH}"
echo "PATH=${FLINK_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
/opt/flink/bin/flink --version

echo "=== Flink installed successfully ==="