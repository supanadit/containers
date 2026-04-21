#!/bin/bash
# cluster.sh - Cluster role helper utilities

# This script is sourced by other entrypoint scripts after logging utilities.
# It provides shared helpers for determining node roles across KRaft mode
# so that orchestration behaves consistently.

# Determine whether this node should be considered the primary/leader.
is_primary_role() {
    log_debug "Determining if node is primary"

    # KRaft mode: controller nodes are considered primary for management tasks
    if [[ "${KAFKA_PROCESS_ROLES:-broker,controller}" == *"controller"* ]]; then
        log_debug "Node has controller role; node is primary"
        return 0
    fi

    # Broker-only nodes are not primary
    if [[ "${KAFKA_PROCESS_ROLES:-broker,controller}" == "broker" ]]; then
        log_debug "Node has broker-only role; node is not primary"
        return 1
    fi

    log_debug "Primary role check failed or indicates replica"
    return 1
}
export -f is_primary_role

# Determine the Kafka backup mode for this node
# Returns: "primary" | "standby-skip" | "disabled"
#
# Backup Strategy:
# - Controller nodes: return "primary" (can manage cluster metadata)
# - Broker-only nodes: return "standby-skip" (skip backup operations)
# - Backup not enabled: return "disabled"
determine_kafka_mode() {
    # Check if backup is enabled
    if is_falsy "${KAFKA_BACKUP_ENABLE:-false}"; then
        echo "disabled"
        return 0
    fi

    # Check if this is a controller node
    if is_primary_role; then
        echo "primary"
        return 0
    fi

    # Broker-only node - skip backup operations
    log_debug "Broker-only node; backup operations skipped"
    echo "standby-skip"
    return 0
}
export -f determine_kafka_mode

# Check if controller host is accessible for cluster coordination
is_controller_accessible() {
    local controller_host="${KAFKA_CONTROLLER_HOST:-}"
    local controller_port="${KAFKA_CONTROLLER_PORT:-9093}"
    
    if [ -z "$controller_host" ]; then
        log_debug "KAFKA_CONTROLLER_HOST not set; controller not accessible"
        return 1
    fi
    
    # Try TCP connection to controller port
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$controller_host" "$controller_port" 2>/dev/null; then
            log_debug "Controller accessible at $controller_host:$controller_port"
            return 0
        fi
    elif command -v timeout >/dev/null 2>&1; then
        if timeout 3 bash -c "echo >/dev/tcp/$controller_host/$controller_port" 2>/dev/null; then
            log_debug "Controller accessible at $controller_host:$controller_port"
            return 0
        fi
    fi
    
    log_debug "Controller not accessible at $controller_host:$controller_port"
    return 1
}
export -f is_controller_accessible
