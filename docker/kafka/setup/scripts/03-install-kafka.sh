#!/bin/bash
set -e

echo "=== Building and installing Kafka ==="

# Set environment variables
export JAVA_HOME=/opt/java
export PATH="${JAVA_HOME}/bin:${PATH}"

# Use KAFKA_VERSION from environment or default
KAFKA_VERSION=${KAFKA_VERSION:-3.9.1}
SCALA_VERSION=${SCALA_VERSION:-2.13}

echo "Installing Apache Kafka ${KAFKA_VERSION}"

# Create temp directory
mkdir -p /temp/sources
cd /temp/sources

# Download Kafka
KAFKA_URL="https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
echo "Downloading from ${KAFKA_URL}"
wget "${KAFKA_URL}"

# Extract Kafka
tar -xzf "kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
KAFKA_DIR="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"

# Move to /opt
mv "${KAFKA_DIR}" /opt/kafka

# Set KAFKA_HOME
export KAFKA_HOME=/opt/kafka
echo "KAFKA_HOME=${KAFKA_HOME}" >> /etc/environment

# Add to PATH
export PATH="${KAFKA_HOME}/bin:${PATH}"
echo "PATH=${KAFKA_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
/opt/kafka/bin/kafka-server-start.sh --version

echo "=== Kafka installed successfully ==="
