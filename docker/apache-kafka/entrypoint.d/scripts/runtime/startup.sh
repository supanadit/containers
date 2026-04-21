#!/bin/bash
# startup.sh - Kafka process startup logic
# Handles startup of Kafka in KRaft mode based on configuration

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/helpers.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh
source /opt/container/entrypoint.d/scripts/utils/cluster.sh

CLUSTER_ID_FILE="/opt/kafka/cluster.id"
CONFIG_FILE="/opt/kafka/config/server.properties"

setup_signal_handlers() {
    log_debug "Setting up signal handlers in startup script"
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP
    log_debug "Signal handlers configured in startup script"
}

handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal in startup script: $signal"
    if [ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi
    exit 0
}

main() {
    log_script_start "startup.sh"

    setup_signal_handlers

    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    if ! validate_security_context; then
        log_error "Security context validation failed"
        return 1
    fi

    select_startup_mode

    log_script_end "startup.sh"
}

select_startup_mode() {
    log_info "Selecting startup mode"

    if is_truthy "${KAFKA_SLEEP_MODE:-false}"; then
        log_info "Sleep mode enabled, entering maintenance mode"
        start_sleep_mode
        return $?
    fi

    start_kafka
    return $?
}

start_kafka() {
    log_info "Starting Kafka in KRaft mode"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Kafka configuration not found: $CONFIG_FILE"
        return 1
    fi

    manage_cluster_id
    format_storage
    run_kafka_server
}

manage_cluster_id() {
    log_info "Managing cluster ID"

    local meta_properties="${KAFKA_DATA_DIR:-/opt/kafka/data}/meta.properties"

    if [ -n "${KAFKA_CLUSTER_ID:-}" ]; then
        log_info "Using provided KAFKA_CLUSTER_ID: ${KAFKA_CLUSTER_ID}"
        if [ -f "$meta_properties" ]; then
            local existing_cluster_id
            existing_cluster_id=$(grep -E "^cluster.id=" "$meta_properties" 2>/dev/null | cut -d'=' -f2)
            if [ -n "$existing_cluster_id" ] && [ "$existing_cluster_id" != "${KAFKA_CLUSTER_ID}" ]; then
                log_error "Data directory has different cluster ID: ${existing_cluster_id}"
                log_error "Provided KAFKA_CLUSTER_ID: ${KAFKA_CLUSTER_ID}"
                log_error "Either unset KAFKA_CLUSTER_ID or clear the data directory"
                return 1
            fi
        fi
        echo "${KAFKA_CLUSTER_ID}" > "${CLUSTER_ID_FILE}"
        return 0
    fi

    if [ -f "$meta_properties" ]; then
        local existing_cluster_id
        existing_cluster_id=$(grep -E "^cluster.id=" "$meta_properties" 2>/dev/null | cut -d'=' -f2)
        if [ -n "$existing_cluster_id" ]; then
            log_info "Using existing cluster ID from data directory: ${existing_cluster_id}"
            echo "${existing_cluster_id}" > "${CLUSTER_ID_FILE}"
            return 0
        fi
    fi

    if [ ! -f "${CLUSTER_ID_FILE}" ]; then
        log_info "Generating new cluster ID..."
        local cluster_id
        cluster_id=$(kafka-storage.sh random-uuid)
        echo "${cluster_id}" > "${CLUSTER_ID_FILE}"
        log_info "Generated cluster ID: ${cluster_id}"
    else
        log_info "Using existing cluster ID from file"
    fi
}

format_storage() {
    local cluster_id
    cluster_id=$(cat "${CLUSTER_ID_FILE}")
    log_info "Formatting storage with cluster ID: ${cluster_id}"

    if kafka-storage.sh format -t "${cluster_id}" -c "${CONFIG_FILE}" --ignore-formatted 2>&1 | grep -q "already formatted"; then
        log_info "Storage already formatted"
    else
        log_info "Storage formatting complete"
    fi
}

run_kafka_server() {
    log_info "Starting Kafka server..."

    export KAFKA_LOG4J_OPTS="${KAFKA_LOG4J_OPTS:--Dlog4j.configuration=file:/opt/kafka/config/log4j.properties}"

    # Handle SASL authentication
    if [[ "${KAFKA_LISTENERS:-PLAINTEXT://:9092,CONTROLLER://:9093}" == *"SASL"* ]]; then
        local jaas_config_file="/opt/kafka/config/kafka_jaas.conf"
        local jaas_config="${KAFKA_SASL_JAAS_CONFIG:-}"
        
        # If KAFKA_SASL_JAAS_CONFIG not set, try listener-specific config
        if [ -z "$jaas_config" ]; then
            # Extract listener name from KAFKA_LISTENERS (e.g., SASL_PLAINTEXT)
            local sasl_listener
            sasl_listener=$(echo "$KAFKA_LISTENERS" | grep -oP '^[A-Z_]+(?=://)' || echo "")
            if [ -n "$sasl_listener" ]; then
                local listener_config_var="KAFKA_CONFIG_LISTENER_NAME_${sasl_listener}_PLAIN_SASL_JAAS_CONFIG"
                listener_config_var=$(echo "$listener_config_var" | tr '[:lower:]' '[:upper:]')
                jaas_config="${!listener_config_var:-}"
                [ -n "$jaas_config" ] && log_info "Using listener-specific JAAS config from $listener_config_var"
            fi
        fi
        
        if [ -n "$jaas_config" ]; then
            log_info "Setting up SASL JAAS configuration"
            # Ensure serviceName is present in the config before the semicolon
            if [[ "$jaas_config" != *"serviceName"* ]]; then
                jaas_config="${jaas_config%;} serviceName=kafka;"
            fi
            printf 'KafkaServer {\n    %s\n};\n' "$jaas_config" > "$jaas_config_file"
            log_info "JAAS config file created: $jaas_config_file"
            log_debug "JAAS config content:"
            log_debug "$(cat "$jaas_config_file")"
            export KAFKA_OPTS="-Djava.security.auth.login.config=${jaas_config_file}"
            log_info "KAFKA_OPTS=$KAFKA_OPTS"
            log_info "Starting Kafka with JAAS config"
            # Verify file before starting
            if [ -f "$jaas_config_file" ]; then
                log_info "JAAS config file exists and is readable"
            else
                log_error "JAAS config file not found: $jaas_config_file"
            fi
            exec kafka-server-start.sh "${CONFIG_FILE}"
        else
            log_warn "SASL listeners configured but KAFKA_SASL_JAAS_CONFIG not set"
            exec kafka-server-start.sh "${CONFIG_FILE}"
        fi
    else
        exec kafka-server-start.sh "${CONFIG_FILE}"
    fi
}

start_sleep_mode() {
    log_info "Entering sleep mode (maintenance)"
    log_environment

    local pid_file="${KAFKA_RUN_DIR:-/tmp/kafka-run}/sleep.pid"
    mkdir -p "$(dirname "$pid_file")"
    echo $$ > "$pid_file"

    log_info "Container is in maintenance mode"
    log_info "Use 'docker exec' to access the container for maintenance tasks"

    while true; do
        sleep 3600
    done
}

main "$@"
