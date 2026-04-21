#!/bin/bash
# 01-directories.sh - Create required Kafka directories with proper permissions

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/helpers.sh

main() {
    log_script_start "01-directories.sh"

    export KAFKA_DATA_DIR="${KAFKA_DATA_DIR:-/opt/kafka/data}"
    export KAFKA_LOG_DIR="${KAFKA_LOG_DIR:-/opt/kafka/logs}"
    export KAFKA_CONFIG_DIR="${KAFKA_CONFIG_DIR:-/opt/kafka/config}"
    export KAFKA_RUN_DIR="${KAFKA_RUN_DIR:-/tmp/kafka-run}"

    local dirs=(
        "$KAFKA_DATA_DIR"
        "$KAFKA_LOG_DIR"
        "$KAFKA_CONFIG_DIR"
        "$KAFKA_RUN_DIR"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_info "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done

    if id kafka >/dev/null 2>&1; then
        for dir in "${dirs[@]}"; do
            chown -R kafka:kafka "$dir" 2>/dev/null || true
        done
    fi

    chmod -R 755 "$KAFKA_DATA_DIR"
    chmod -R 755 "$KAFKA_LOG_DIR"

    log_script_end "01-directories.sh"
}

main "$@"
