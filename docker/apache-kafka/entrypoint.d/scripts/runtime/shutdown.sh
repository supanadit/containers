#!/bin/bash
# shutdown.sh - Graceful Kafka shutdown handling
# Manages shutdown process with timeout and cleanup

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

DEFAULT_SHUTDOWN_TIMEOUT=30

main() {
    log_script_start "shutdown.sh"

    local timeout="${TIMEOUT:-$DEFAULT_SHUTDOWN_TIMEOUT}"

    log_info "Initiating graceful shutdown (timeout: ${timeout}s)"

    initiate_graceful_shutdown "$timeout"

    wait_for_shutdown "$timeout"

    force_shutdown_if_needed

    cleanup_resources

    log_script_end "shutdown.sh"
}

initiate_graceful_shutdown() {
    local timeout="$1"

    log_info "Sending SIGTERM to Kafka processes"

    local kafka_pids
    kafka_pids=$(pgrep -f "kafka.Kafka" || pgrep -f "kafka-server-start" || true)

    if [ -z "$kafka_pids" ]; then
        log_info "No Kafka processes found"
        return 0
    fi

    echo "$kafka_pids" | while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_debug "Sending SIGTERM to Kafka process: $pid"
            kill -TERM "$pid" || true
        fi
    done
}

wait_for_shutdown() {
    local timeout="$1"
    local start_time
    start_time=$(date +%s)

    log_debug "Waiting for processes to shutdown (timeout: ${timeout}s)"

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $timeout ]; then
            log_warn "Shutdown timeout reached (${timeout}s)"
            return 1
        fi

        if ! pgrep -f "kafka.Kafka" >/dev/null 2>&1 && \
           ! pgrep -f "kafka-server-start" >/dev/null 2>&1; then
            log_info "All processes have shut down gracefully"
            return 0
        fi

        sleep 1
    done
}

force_shutdown_if_needed() {
    log_warn "Forcing shutdown of remaining processes"

    local remaining_pids
    remaining_pids=$(pgrep -f "kafka.Kafka" || pgrep -f "kafka-server-start" || true)

    if [ -n "$remaining_pids" ]; then
        log_warn "Sending SIGKILL to remaining Kafka processes"
        echo "$remaining_pids" | while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_error "Force killing Kafka process: $pid"
                kill -KILL "$pid" || true
            fi
        done
    fi

    log_info "Resource cleanup completed"
}

cleanup_resources() {
    log_debug "Cleaning up PID files"

    local run_dir="${KAFKA_RUN_DIR:-/tmp/kafka-run}"

    local pid_file="$run_dir/kafka.pid"
    if [ -f "$pid_file" ]; then
        rm -f "$pid_file"
        log_debug "Removed PID file: $pid_file"
    fi

    local sleep_pid_file="$run_dir/sleep.pid"
    if [ -f "$sleep_pid_file" ]; then
        rm -f "$sleep_pid_file"
        log_debug "Removed sleep PID file: $sleep_pid_file"
    fi

    log_debug "Cleaning up temporary files"

    if [ -f "/tmp/kafka-pass" ]; then
        secure_cleanup "/tmp/kafka-pass"
        log_debug "Cleaned up kafka-pass file"
    fi
}

main "$@"
