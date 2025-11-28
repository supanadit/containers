#!/bin/bash
set -e

# Set environment variables
export JAVA_HOME=/opt/java
export FLINK_HOME=/opt/flink
export PATH="${JAVA_HOME}/bin:${FLINK_HOME}/bin:${PATH}"

CONFIG_JOBMANAGER_RPC_ADDRESS="${CONFIG_JOBMANAGER_RPC_ADDRESS:-localhost}"
CONFIG_JOBMANAGER_RPC_PORT="${CONFIG_JOBMANAGER_RPC_PORT:-6123}"
CONFIG_JOBMANAGER_MEMORY_PROCESS_SIZE="${CONFIG_JOBMANAGER_MEMORY_PROCESS_SIZE:-1600m}"

CONFIG_TASKMANAGER_MEMORY_PROCESS_SIZE="${CONFIG_TASKMANAGER_MEMORY_PROCESS_SIZE:-1728m}"
CONFIG_TASKMANAGER_NUMBER_OF_TASK_SLOTS="${CONFIG_TASKMANAGER_NUMBER_OF_TASK_SLOTS:-1}"

CONFIG_PARALLELISM_DEFAULT="${CONFIG_PARALLELISM_DEFAULT:-1}"

CONFIG_REST_ADDRESS="${CONFIG_REST_ADDRESS:-0.0.0.0}"
CONFIG_REST_PORT="${CONFIG_REST_PORT:-8081}"

CONFIG_STATE_BACKEND="${CONFIG_STATE_BACKEND:-filesystem}"
CONFIG_STATE_CHECKPOINTS_DIR="${CONFIG_STATE_CHECKPOINTS_DIR:-file:///opt/flink/checkpoints}"
CONFIG_STATE_SAVEPOINTS_DIR="${CONFIG_STATE_SAVEPOINTS_DIR:-file:///opt/flink/savepoints}"

CONFIG_LOG_FILE="${CONFIG_LOG_FILE:-/opt/flink/logs/flink.log}"

# Create necessary directories
mkdir -p /opt/flink/logs

# Set Flink configuration
export FLINK_CONF_DIR=/opt/flink/conf

# Generate flink-conf.yaml from CONFIG_ variables
FLINK_CONF_FILE="${FLINK_CONF_DIR}/flink-conf.yaml"
mkdir -p "${FLINK_CONF_DIR}"
: > "${FLINK_CONF_FILE}" # Truncate file

for var in $(compgen -v CONFIG_); do
    value="${!var}"
    # Remove CONFIG_ prefix, convert to lowercase, replace _ with .
    key="$(echo "${var#CONFIG_}" | tr '[:upper:]' '[:lower:]' | tr '_' '.')"
    echo "${key}: ${value}" >> "${FLINK_CONF_FILE}"
done


# Start Flink cluster in standalone mode
echo "Starting Flink standalone cluster..."
# Start TaskManager in background
${FLINK_HOME}/bin/taskmanager.sh start
# Start JobManager in foreground
exec ${FLINK_HOME}/bin/jobmanager.sh start-foreground