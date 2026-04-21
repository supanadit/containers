#!/bin/bash
# validation.sh - Configuration and environment validation utilities
# Provides validation functions for all container scripts

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/helpers.sh

DEFAULT_KAFKA_DATA_DIR="/opt/kafka/data"
DEFAULT_KAFKA_CONFIG_DIR="/opt/kafka/config"
DEFAULT_TIMEOUT=30

validate_environment() {
    local exit_code=0

    log_debug "Validating environment variables"

    if [ -z "${KAFKA_DATA_DIR:-}" ]; then
        KAFKA_DATA_DIR="$DEFAULT_KAFKA_DATA_DIR"
        log_info "KAFKA_DATA_DIR not set, using default: $KAFKA_DATA_DIR"
    fi

    if [ ! -d "$KAFKA_DATA_DIR" ] && [ ! -w "$(dirname "$KAFKA_DATA_DIR")" ]; then
        log_error "KAFKA_DATA_DIR directory is not writable: $KAFKA_DATA_DIR"
        return 1
    fi

    if [ -z "${KAFKA_CONFIG_DIR:-}" ]; then
        KAFKA_CONFIG_DIR="$DEFAULT_KAFKA_CONFIG_DIR"
        log_info "KAFKA_CONFIG_DIR not set, using default: $KAFKA_CONFIG_DIR"
    fi

    case "${LOG_LEVEL:-INFO}" in
        DEBUG|INFO|WARN|ERROR) ;;
        *)
            log_error "Invalid LOG_LEVEL: $LOG_LEVEL (must be DEBUG, INFO, WARN, or ERROR)"
            exit_code=1
            ;;
    esac

    if [ -z "${TIMEOUT:-}" ]; then
        TIMEOUT="$DEFAULT_TIMEOUT"
    elif ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -le 0 ]; then
        log_error "Invalid TIMEOUT: $TIMEOUT (must be a positive integer)"
        exit_code=1
    fi

    if [ -z "${KAFKA_NODE_ID:-}" ]; then
        KAFKA_NODE_ID="1"
        log_info "KAFKA_NODE_ID not set, using default: $KAFKA_NODE_ID"
    elif ! [[ "$KAFKA_NODE_ID" =~ ^[0-9]+$ ]]; then
        log_error "Invalid KAFKA_NODE_ID: $KAFKA_NODE_ID (must be a non-negative integer)"
        exit_code=1
    fi

    local process_roles_raw="${KAFKA_PROCESS_ROLES:-broker,controller}"
    IFS=',' read -ra roles <<< "$process_roles_raw"
    for role in "${roles[@]}"; do
        case "$role" in
            broker|controller) ;;
            *)
                log_error "Invalid role in KAFKA_PROCESS_ROLES: $role (must be broker and/or controller)"
                exit_code=1
                ;;
        esac
    done

    if [ -n "${KAFKA_NUM_NETWORK_THREADS:-}" ]; then
        if ! [[ "$KAFKA_NUM_NETWORK_THREADS" =~ ^[0-9]+$ ]] || [ "$KAFKA_NUM_NETWORK_THREADS" -le 0 ]; then
            log_error "Invalid KAFKA_NUM_NETWORK_THREADS: $KAFKA_NUM_NETWORK_THREADS (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_NUM_IO_THREADS:-}" ]; then
        if ! [[ "$KAFKA_NUM_IO_THREADS" =~ ^[0-9]+$ ]] || [ "$KAFKA_NUM_IO_THREADS" -le 0 ]; then
            log_error "Invalid KAFKA_NUM_IO_THREADS: $KAFKA_NUM_IO_THREADS (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_NUM_PARTITIONS:-}" ]; then
        if ! [[ "$KAFKA_NUM_PARTITIONS" =~ ^[0-9]+$ ]] || [ "$KAFKA_NUM_PARTITIONS" -le 0 ]; then
            log_error "Invalid KAFKA_NUM_PARTITIONS: $KAFKA_NUM_PARTITIONS (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_LOG_RETENTION_HOURS:-}" ]; then
        if ! [[ "$KAFKA_LOG_RETENTION_HOURS" =~ ^[0-9]+$ ]]; then
            log_error "Invalid KAFKA_LOG_RETENTION_HOURS: $KAFKA_LOG_RETENTION_HOURS (must be a non-negative integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_LOG_SEGMENT_BYTES:-}" ]; then
        if ! validate_memory_value "$KAFKA_LOG_SEGMENT_BYTES"; then
            log_error "Invalid KAFKA_LOG_SEGMENT_BYTES: $KAFKA_LOG_SEGMENT_BYTES (must be a valid byte value)"
            exit_code=1
        fi
    fi

    case "${KAFKA_SLEEP_MODE:-false}" in
        true|false) ;;
        *)
            log_error "Invalid KAFKA_SLEEP_MODE: $KAFKA_SLEEP_MODE (must be true or false)"
            exit_code=1
            ;;
    esac

    if [ -n "${KAFKA_SOCKET_SEND_BUFFER_BYTES:-}" ]; then
        if ! [[ "$KAFKA_SOCKET_SEND_BUFFER_BYTES" =~ ^[0-9]+$ ]] || [ "$KAFKA_SOCKET_SEND_BUFFER_BYTES" -le 0 ]; then
            log_error "Invalid KAFKA_SOCKET_SEND_BUFFER_BYTES: $KAFKA_SOCKET_SEND_BUFFER_BYTES (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_SOCKET_RECEIVE_BUFFER_BYTES:-}" ]; then
        if ! [[ "$KAFKA_SOCKET_RECEIVE_BUFFER_BYTES" =~ ^[0-9]+$ ]] || [ "$KAFKA_SOCKET_RECEIVE_BUFFER_BYTES" -le 0 ]; then
            log_error "Invalid KAFKA_SOCKET_RECEIVE_BUFFER_BYTES: $KAFKA_SOCKET_RECEIVE_BUFFER_BYTES (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_SOCKET_REQUEST_MAX_BYTES:-}" ]; then
        if ! validate_memory_value "$KAFKA_SOCKET_REQUEST_MAX_BYTES"; then
            log_error "Invalid KAFKA_SOCKET_REQUEST_MAX_BYTES: $KAFKA_SOCKET_REQUEST_MAX_BYTES (must be a valid byte value)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR:-}" ]; then
        if ! [[ "$KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR" =~ ^[0-9]+$ ]] || [ "$KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR" -lt 1 ]; then
            log_error "Invalid KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: $KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR:-}" ]; then
        if ! [[ "$KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR" =~ ^[0-9]+$ ]] || [ "$KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR" -lt 1 ]; then
            log_error "Invalid KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: $KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_TRANSACTION_STATE_LOG_MIN_ISR:-}" ]; then
        if ! [[ "$KAFKA_TRANSACTION_STATE_LOG_MIN_ISR" =~ ^[0-9]+$ ]] || [ "$KAFKA_TRANSACTION_STATE_LOG_MIN_ISR" -lt 1 ]; then
            log_error "Invalid KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: $KAFKA_TRANSACTION_STATE_LOG_MIN_ISR (must be a positive integer)"
            exit_code=1
        fi
    fi

    if [ -n "${KAFKA_CONTROLLER_QUORUM_VOTERS:-}" ]; then
        if ! validate_quorum_voters "$KAFKA_CONTROLLER_QUORUM_VOTERS"; then
            log_error "Invalid KAFKA_CONTROLLER_QUORUM_VOTERS: $KAFKA_CONTROLLER_QUORUM_VOTERS (must be format: id@host:port[,id@host:port...])"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

validate_dependencies() {
    local exit_code=0

    log_debug "Validating required dependencies"

    local required_commands=("java" "kafka-server-start.sh" "kafka-storage.sh")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit_code=1
        fi
    done

    return "$exit_code"
}

validate_memory_value() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+(B|KB|MB|GB|TB)?$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_permissions() {
    local exit_code=0

    log_debug "Validating file and directory permissions"

    if [ -d "${KAFKA_DATA_DIR:-}" ]; then
        local data_perms
        data_perms=$(stat -c "%a" "$KAFKA_DATA_DIR" 2>/dev/null || echo "unknown")
        if [ "$data_perms" != "700" ] && [ "$data_perms" != "755" ]; then
            log_warn "KAFKA_DATA_DIR permissions are not ideal: $data_perms (recommended: 700 or 755)"
        fi
    fi

    local config_file="/opt/kafka/config/server.properties"
    if [ -f "$config_file" ]; then
        local file_perms
        file_perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "unknown")
        if [ "$file_perms" = "777" ] || [ "$file_perms" = "666" ]; then
            log_error "Insecure permissions on config file: $config_file ($file_perms)"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

validate_quorum_voters() {
    local quorum_voters="$1"

    if [ -z "$quorum_voters" ]; then
        return 1
    fi

    IFS=',' read -ra voters <<< "$quorum_voters"
    for voter in "${voters[@]}"; do
        if ! [[ "$voter" =~ ^[0-9]+@[^:]+:[0-9]+$ ]]; then
            return 1
        fi
    done

    return 0
}

validate_config_files() {
    local exit_code=0

    log_debug "Validating configuration files"

    if [ -n "${KAFKA_CONFIG_DIR:-}" ] && [ ! -d "$KAFKA_CONFIG_DIR" ]; then
        log_warn "Configuration directory does not exist: $KAFKA_CONFIG_DIR"
        return 0
    fi

    local server_props="${KAFKA_CONFIG_DIR:-}/server.properties"
    if [ -f "$server_props" ]; then
        if ! validate_server_properties "$server_props"; then
            log_error "Invalid server.properties: $server_props"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

validate_server_properties() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_error "Server properties file does not exist: $config_file"
        return 1
    fi

    if [ ! -r "$config_file" ]; then
        log_error "Server properties file is not readable: $config_file"
        return 1
    fi

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
            local param="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            log_debug "Validated parameter: $param = $value"
        fi
    done < "$config_file"

    return 0
}

export -f validate_environment
export -f validate_dependencies
export -f validate_memory_value
export -f validate_permissions
export -f validate_quorum_voters
export -f validate_config_files
export -f validate_server_properties
