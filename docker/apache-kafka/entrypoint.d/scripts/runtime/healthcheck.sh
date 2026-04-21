#!/bin/bash
# healthcheck.sh - Container health monitoring for Kafka
# Provides health status checks for Kafka broker and controller

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh
source /opt/container/entrypoint.d/scripts/utils/helpers.sh

HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

main() {
    local check_type="${1:-comprehensive}"

    case "$check_type" in
        "kafka")
            check_kafka_connectivity
            ;;
        "disk")
            check_disk_space
            ;;
        "process")
            check_process_health
            ;;
        "comprehensive"|*)
            comprehensive_health_check
            ;;
    esac
}

comprehensive_health_check() {
    local overall_status=$HEALTH_OK
    local issues=()

    log_debug "Running comprehensive health check"

    if ! check_kafka_connectivity; then
        overall_status=$HEALTH_CRITICAL
        issues+=("kafka_connectivity")
    fi

    if ! check_disk_space; then
        overall_status=$HEALTH_WARNING
        issues+=("disk_space")
    fi

    if ! check_process_health; then
        overall_status=$HEALTH_CRITICAL
        issues+=("process_health")
    fi

    if [ $overall_status -eq $HEALTH_OK ]; then
        echo "OK - All health checks passed"
        exit $HEALTH_OK
    else
        echo "CRITICAL - Health check failures: ${issues[*]}"
        exit $overall_status
    fi
}

check_kafka_connectivity() {
    log_debug "Checking Kafka connectivity"

    local port="${KAFKA_PORT:-9092}"
    local host="${KAFKA_CONNECT_HOST:-localhost}"

    # Try to connect to Kafka port
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "$host" "$port" 2>/dev/null; then
            log_debug "Kafka is accepting connections on $host:$port"
            return 0
        else
            log_error "Kafka is not accepting connections on $host:$port"
            return 1
        fi
    elif command -v bash >/dev/null 2>&1; then
        if (echo > /dev/tcp/"$host"/"$port") 2>/dev/null; then
            log_debug "Kafka is accepting connections on $host:$port"
            return 0
        else
            log_error "Kafka is not accepting connections on $host:$port"
            return 1
        fi
    else
        # Fallback: check if process is running
        if pgrep -f "kafka.Kafka" >/dev/null 2>&1 || pgrep -f "kafka-server-start" >/dev/null 2>&1; then
            log_debug "Kafka process is running (port check unavailable)"
            return 0
        else
            log_error "Kafka process is not running"
            return 1
        fi
    fi
}

check_disk_space() {
    log_debug "Checking disk space"

    local data_dir="${KAFKA_DATA_DIR:-/opt/kafka/data}"
    local min_free_percent=10
    local min_free_mb=100

    local mount_point
    mount_point=$(df -P "$data_dir" | tail -1 | awk '{print $6}')

    local df_usage df_usage_mb used_percent free_percent free_mb
    df_usage=$(df -P "$mount_point" | tail -1)
    used_percent=$(awk '{print $5}' <<<"$df_usage" | tr -d '%')
    free_percent=$((100 - used_percent))

    df_usage_mb=$(df -Pm "$mount_point" | tail -1)
    free_mb=$(awk '{print $4}' <<<"$df_usage_mb")

    log_debug "Disk space check: ${free_percent}% free, ${free_mb}MB free on $mount_point"

    if [ "$free_percent" -lt "$min_free_percent" ] && [ "$free_mb" -lt "$min_free_mb" ]; then
        log_error "Low disk space: ${free_percent}% free, ${free_mb}MB free"
        return 1
    fi

    return 0
}

check_process_health() {
    log_debug "Checking process health"

    local kafka_processes
    kafka_processes=$(pgrep -f "kafka.Kafka" 2>/dev/null | wc -l || echo "0")
    kafka_processes_alt=$(pgrep -f "kafka-server-start" 2>/dev/null | wc -l || echo "0")
    local total_processes=$((kafka_processes + kafka_processes_alt))

    if [ "$total_processes" -eq 0 ]; then
        log_error "No Kafka processes found"
        return 1
    else
        log_debug "Found $total_processes Kafka process(es)"
    fi

    # Check for zombie processes
    local zombie_count
    zombie_count=$(ps aux | awk '{print $8}' | grep -c "Z" || true)

    if [ "$zombie_count" -gt 0 ]; then
        log_warn "Found $zombie_count zombie process(es)"
    fi

    # Check Java memory usage
    local memory_usage
    memory_usage=$(ps -C java -o pmem= 2>/dev/null | awk '{sum+=$1} END {if (NR==0) print 0; else print sum}')
    memory_usage=${memory_usage:-0}

    if awk "BEGIN { exit !($memory_usage > 90) }" 2>/dev/null; then
        log_error "High memory usage by Kafka processes: ${memory_usage}%"
        return 1
    fi

    return 0
}

main "$@"
