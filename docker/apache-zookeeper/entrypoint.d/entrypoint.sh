#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export ZOOKEEPER_HOME=/opt/zookeeper
export PATH="${JAVA_HOME}/bin:${ZOOKEEPER_HOME}/bin:${PATH}"

# Create necessary directories (normalized paths)
mkdir -p /opt/containers/logs /opt/containers/data

# Set ZooKeeper configuration directory (normalized path)
export ZOOCFGDIR=${ZOOCFGDIR:-/opt/containers/config}

# Copy default zoo.cfg to config directory if not already present
if [ ! -f "${ZOOCFGDIR}/zoo.cfg" ]; then
    mkdir -p "${ZOOCFGDIR}"
    cp /opt/zookeeper/conf/zoo.cfg "${ZOOCFGDIR}/zoo.cfg"
fi

# Start ZooKeeper server
echo "Starting ZooKeeper server..."
exec zkServer.sh start-foreground