#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export KAFKA_HOME=/opt/kafka
export PATH="${JAVA_HOME}/bin:${KAFKA_HOME}/bin:${PATH}"

# Create necessary directories
mkdir -p /tmp/kafka-logs
mkdir -p /opt/kafka/data

# Configuration file
CONFIG_FILE="/opt/kafka/config/server.properties"

# Cluster ID file
CLUSTER_ID_FILE="/opt/kafka/cluster.id"

# Generate cluster ID if not exists
if [ ! -f "${CLUSTER_ID_FILE}" ]; then
    echo "Generating new cluster ID..."
    CLUSTER_ID=$(${KAFKA_HOME}/bin/kafka-storage.sh random-uuid)
    echo "${CLUSTER_ID}" > "${CLUSTER_ID_FILE}"
else
    CLUSTER_ID=$(cat "${CLUSTER_ID_FILE}")
fi

echo "Using cluster ID: ${CLUSTER_ID}"

# Format storage
echo "Formatting storage..."
${KAFKA_HOME}/bin/kafka-storage.sh format -t "${CLUSTER_ID}" -c "${CONFIG_FILE}" --ignore-formatted

# Start Kafka in KRaft mode
echo "Starting Kafka server..."
exec ${KAFKA_HOME}/bin/kafka-server-start.sh "${CONFIG_FILE}"