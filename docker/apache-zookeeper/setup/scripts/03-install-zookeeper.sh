#!/bin/bash
set -e

echo "=== Building and installing ZooKeeper ==="

# Use ZOOKEEPER_VERSION from environment or default to 3.9.4
ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION:-3.9.4}

echo "Installing Apache ZooKeeper ${ZOOKEEPER_VERSION}"

# Create temp directory
mkdir -p /temp/sources
cd /temp/sources

# Download Apache ZooKeeper
ZOOKEEPER_URL="https://downloads.apache.org/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"
echo "Downloading from ${ZOOKEEPER_URL}"
curl -L -o zookeeper.tar.gz "${ZOOKEEPER_URL}"

# Extract ZooKeeper
tar -xzf zookeeper.tar.gz
ZOOKEEPER_DIR=$(tar -tf zookeeper.tar.gz | head -1 | cut -d'/' -f1)

# Move to /opt
mv "${ZOOKEEPER_DIR}" /opt/zookeeper

# Set ZOOKEEPER_HOME
export ZOOKEEPER_HOME=/opt/zookeeper
echo "ZOOKEEPER_HOME=${ZOOKEEPER_HOME}" >> /etc/environment

# Add to PATH
export PATH="${ZOOKEEPER_HOME}/bin:${PATH}"
echo "PATH=${ZOOKEEPER_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
/opt/zookeeper/bin/zkServer.sh version

echo "=== ZooKeeper installed successfully ==="