#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export ZOOKEEPER_HOME=/opt/zookeeper
export PATH="${JAVA_HOME}/bin:${ZOOKEEPER_HOME}/bin:${PATH}"

# Create necessary directories
mkdir -p /opt/zookeeper/logs /opt/zookeeper/data

# Set ZooKeeper configuration
export ZOOCFGDIR=/opt/zookeeper/conf

# Start ZooKeeper server
echo "Starting ZooKeeper server..."
exec zkServer.sh start-foreground