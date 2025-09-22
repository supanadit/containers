#!/bin/bash
# healthcheck.sh - Container health monitoring
# Provides health status checks for PostgreSQL and related services

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Exit codes for health checks
HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

# Main function
main() {
    local check_type="${1:-comprehensive}"

    case "$check_type" in
        "postgresql")
            check_postgresql_connectivity
            ;;
        "patroni")
            check_patroni_status
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

# Comprehensive health check
comprehensive_health_check() {
    local overall_status=$HEALTH_OK
    local issues=()

    log_debug "Running comprehensive health check"

    # Check PostgreSQL connectivity
    if ! check_postgresql_connectivity; then
        overall_status=$HEALTH_CRITICAL
        issues+=("postgresql_connectivity")
    fi

    # Check Patroni status if enabled
    if [ "${USE_PATRONI:-false}" = "true" ]; then
        if ! check_patroni_status; then
            overall_status=$HEALTH_CRITICAL
            issues+=("patroni_status")
        fi
    fi

    # Check disk space
    if ! check_disk_space; then
        overall_status=$HEALTH_WARNING
        issues+=("disk_space")
    fi

    # Check process health
    if ! check_process_health; then
        overall_status=$HEALTH_CRITICAL
        issues+=("process_health")
    fi

    # Report results
    if [ $overall_status -eq $HEALTH_OK ]; then
        echo "OK - All health checks passed"
        exit $HEALTH_OK
    else
        echo "CRITICAL - Health check failures: ${issues[*]}"
        exit $overall_status
    fi
}

# Check PostgreSQL connectivity
check_postgresql_connectivity() {
    log_debug "Checking PostgreSQL connectivity"

    local port="${POSTGRESQL_PORT:-5432}"
    local host="${POSTGRESQL_CONNECT_HOST:-localhost}"
    local user="${POSTGRES_USER:-postgres}"

    # Use pg_isready for basic connectivity check
    if pg_isready -h "$host" -p "$port" -U "$user" -t 5 >/dev/null 2>&1; then
        log_debug "PostgreSQL is accepting connections"
        return 0
    else
        log_error "PostgreSQL is not accepting connections"
        return 1
    fi
}

# Check Patroni cluster status
check_patroni_status() {
    log_debug "Checking Patroni status"

    # Check if Patroni is running
    if ! pgrep -f "patroni" >/dev/null 2>&1; then
        log_error "Patroni process is not running"
        return 1
    fi

    # Try to get Patroni status via REST API
    local rest_port="${PATRONI_REST_PORT:-8008}"
    local rest_host="${PATRONI_REST_HOST:-localhost}"

    if command -v curl >/dev/null 2>&1; then
        local status_url="http://$rest_host:$rest_port/patroni"
        local response
        response=$(curl -s -w "%{http_code}" -o /dev/null "$status_url" 2>/dev/null || echo "000")

        if [ "$response" = "200" ]; then
            log_debug "Patroni REST API is responding"
            return 0
        else
            log_error "Patroni REST API is not responding (HTTP $response)"
            return 1
        fi
    else
        log_warn "curl not available, skipping Patroni REST API check"
        # Consider Patroni healthy if process is running
        return 0
    fi
}

# Check disk space availability
check_disk_space() {
    log_debug "Checking disk space"

    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local min_free_percent=10
    local min_free_mb=100

    # Get disk usage for the data directory
    local mount_point
    mount_point=$(df "$data_dir" | tail -1 | awk '{print $6}')

    local free_percent
    free_percent=$(df "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')

    local free_mb
    free_mb=$(df -m "$mount_point" | tail -1 | awk '{print $4}')

    log_debug "Disk space check: $free_percent% free, ${free_mb}MB free on $mount_point"

    # Check thresholds
    if [ "$free_percent" -lt "$min_free_percent" ] || [ "$free_mb" -lt "$min_free_mb" ]; then
        log_error "Low disk space: ${free_percent}% free, ${free_mb}MB free"
        return 1
    fi

    return 0
}

# Check process health
check_process_health() {
    log_debug "Checking process health"

    # Check for PostgreSQL processes
    local pg_processes
    pg_processes=$(pgrep -f "postgres" | wc -l)

    if [ "$pg_processes" -eq 0 ]; then
        # If Patroni is enabled, PostgreSQL might not be running directly
        if [ "${USE_PATRONI:-false}" = "true" ]; then
            log_debug "PostgreSQL not running directly (Patroni mode)"
        else
            log_error "No PostgreSQL processes found"
            return 1
        fi
    else
        log_debug "Found $pg_processes PostgreSQL process(es)"
    fi

    # Check for zombie processes
    local zombie_count
    zombie_count=$(ps aux | awk '{print $8}' | grep -c "Z" || true)

    if [ "$zombie_count" -gt 0 ]; then
        log_warn "Found $zombie_count zombie process(es)"
        # Don't fail for zombies, just warn
    fi

    # Check memory usage (basic check)
    local memory_usage
    memory_usage=$(ps aux --no-headers -o pmem -C postgres | awk '{sum+=$1} END {print sum}' 2>/dev/null || echo "0")

    if [ "$(echo "$memory_usage > 90" | bc 2>/dev/null || echo "0")" = "1" ]; then
        log_error "High memory usage by PostgreSQL processes: ${memory_usage}%"
        return 1
    fi

    return 0
}

# Execute main function with arguments
main "$@"