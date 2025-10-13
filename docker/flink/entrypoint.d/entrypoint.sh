#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export FLINK_HOME=/opt/flink
export PATH="${JAVA_HOME}/bin:${FLINK_HOME}/bin:${PATH}"

# Create necessary directories
mkdir -p /opt/flink/logs

# Set Flink configuration
export FLINK_CONF_DIR=/opt/flink/conf

# Start Flink cluster in standalone mode
echo "Starting Flink standalone cluster..."
# Start TaskManager in background
${FLINK_HOME}/bin/taskmanager.sh start
# Start JobManager in foreground
exec ${FLINK_HOME}/bin/jobmanager.sh start-foreground