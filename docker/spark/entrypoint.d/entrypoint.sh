#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export SPARK_HOME=/opt/spark
export PATH="${JAVA_HOME}/bin:${SPARK_HOME}/bin:${PATH}"

# Create necessary directories
mkdir -p /tmp/spark-logs
mkdir -p /opt/spark/work

# Start Spark master in background
echo "Starting Spark master..."
${SPARK_HOME}/sbin/start-master.sh &

# Wait for master to start
sleep 10

# Start Spark worker
echo "Starting Spark worker..."
${SPARK_HOME}/sbin/start-worker.sh spark://localhost:7077 &

# Keep the container running
echo "Spark cluster started. Master UI at http://localhost:8080"
tail -f /opt/spark/logs/*