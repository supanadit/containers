#!/bin/bash
# entrypoint.sh - Main container orchestrator
# Coordinates all modular scripts for Kafka container initialization and runtime

# Set strict error handling
set -euo pipefail

# Source utility functions first
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh
source /opt/container/entrypoint.d/scripts/utils/cluster.sh

# Script version
SCRIPT_VERSION="1.0.0"

# Default directories
export DEFAULT_KAFKA_DATA_DIR="${DEFAULT_KAFKA_DATA_DIR:-/opt/kafka/data}"
export DEFAULT_KAFKA_LOG_DIR="${DEFAULT_KAFKA_LOG_DIR:-/opt/kafka/logs}"
export DEFAULT_KAFKA_CONFIG_DIR="${DEFAULT_KAFKA_CONFIG_DIR:-/opt/kafka/config}"
export DEFAULT_KAFKA_RUN_DIR="${DEFAULT_KAFKA_RUN_DIR:-/tmp/kafka-run}"

# Set actual variables used by scripts
export KAFKA_DATA_DIR="$DEFAULT_KAFKA_DATA_DIR"
export KAFKA_LOG_DIR="$DEFAULT_KAFKA_LOG_DIR"
export KAFKA_CONFIG_DIR="$DEFAULT_KAFKA_CONFIG_DIR"
export KAFKA_RUN_DIR="$DEFAULT_KAFKA_RUN_DIR"

# Kafka configuration environment variables
export KAFKA_NODE_ID="${KAFKA_NODE_ID:-1}"
export KAFKA_PROCESS_ROLES="${KAFKA_PROCESS_ROLES:-broker,controller}"
export KAFKA_CONTROLLER_QUORUM_VOTERS="${KAFKA_CONTROLLER_QUORUM_VOTERS:-1@localhost:9093}"
export KAFKA_CONTROLLER_LISTENER_NAMES="${KAFKA_CONTROLLER_LISTENER_NAMES:-CONTROLLER}"
export KAFKA_LISTENERS="${KAFKA_LISTENERS:-PLAINTEXT://:9092,CONTROLLER://:9093}"
export KAFKA_INTER_BROKER_LISTENER_NAME="${KAFKA_INTER_BROKER_LISTENER_NAME:-PLAINTEXT}"
export KAFKA_ADVERTISED_LISTENERS="${KAFKA_ADVERTISED_LISTENERS:-PLAINTEXT://localhost:9092}"
export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="${KAFKA_LISTENER_SECURITY_PROTOCOL_MAP:-CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL}"

# Performance configuration
export KAFKA_NUM_NETWORK_THREADS="${KAFKA_NUM_NETWORK_THREADS:-3}"
export KAFKA_NUM_IO_THREADS="${KAFKA_NUM_IO_THREADS:-8}"
export KAFKA_SOCKET_SEND_BUFFER_BYTES="${KAFKA_SOCKET_SEND_BUFFER_BYTES:-102400}"
export KAFKA_SOCKET_RECEIVE_BUFFER_BYTES="${KAFKA_SOCKET_RECEIVE_BUFFER_BYTES:-102400}"
export KAFKA_SOCKET_REQUEST_MAX_BYTES="${KAFKA_SOCKET_REQUEST_MAX_BYTES:-104857600}"
export KAFKA_NUM_PARTITIONS="${KAFKA_NUM_PARTITIONS:-1}"
export KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR="${KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR:-1}"
export KAFKA_LOG_DIRS="${KAFKA_LOG_DIRS:-/opt/kafka/data}"
export KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR="${KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR:-1}"
export KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR="${KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR:-1}"
export KAFKA_TRANSACTION_STATE_LOG_MIN_ISR="${KAFKA_TRANSACTION_STATE_LOG_MIN_ISR:-1}"
export KAFKA_LOG_RETENTION_HOURS="${KAFKA_LOG_RETENTION_HOURS:-168}"
export KAFKA_LOG_SEGMENT_BYTES="${KAFKA_LOG_SEGMENT_BYTES:-1073741824}"
export KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS="${KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS:-300000}"
export KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS="${KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS:-0}"

# Feature flags
export KAFKA_AUTO_CREATE_TOPICS_ENABLE="${KAFKA_AUTO_CREATE_TOPICS_ENABLE:-true}"
export KAFKA_DELETE_TOPIC_ENABLE="${KAFKA_DELETE_TOPIC_ENABLE:-true}"

# Timeouts
export KAFKA_READY_MAX_ATTEMPTS="${KAFKA_READY_MAX_ATTEMPTS:-30}"
export KAFKA_READY_ATTEMPT_INTERVAL="${KAFKA_READY_ATTEMPT_INTERVAL:-1}"

# Set environment variables for Java and Kafka
export JAVA_HOME=/opt/java
export KAFKA_HOME=/opt/kafka
export PATH="${JAVA_HOME}/bin:${KAFKA_HOME}/bin:${PATH}"

# Main function
main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"

    # Log startup information
    log_info "Kafka Container Entrypoint v$SCRIPT_VERSION"
    log_environment

    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi

    # Validate dependencies
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi

    # Set up signal handlers
    setup_signal_handlers

    # Run initialization scripts in order
    run_initialization

    # Start runtime management
    start_runtime

    log_script_end "entrypoint.sh"
}

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    log_debug "Setting up signal handlers"

    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP

    log_debug "Signal handlers configured"
}

# Handle shutdown signals
handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"

    # Run shutdown script
    if [ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi

    log_info "Shutdown complete"
    exit 0
}

# Run initialization scripts in order
run_initialization() {
    log_info "Running initialization scripts"

    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/00-misc-scripts.sh"
        "/opt/container/entrypoint.d/scripts/init/01-directories.sh"
        "/opt/container/entrypoint.d/scripts/init/02-config.sh"
    )

    for script in "${init_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Running initialization script: $(basename "$script")"
            if ! "$script"; then
                log_error "Initialization script failed: $(basename "$script")"
                exit 1
            fi
        else
            log_warn "Initialization script not found or not executable: $script"
        fi
    done

    log_info "All initialization scripts completed successfully"
}

# Start runtime management
start_runtime() {
    log_info "Starting runtime management"

    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"

    if [ -f "$startup_script" ] && [ -x "$startup_script" ]; then
        log_info "Starting Kafka via startup script"
        exec "$startup_script"
    else
        log_error "Startup script not found or not executable: $startup_script"
        exit 1
    fi
}

# Execute main function
main "$@"
