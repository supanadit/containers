#!/bin/bash
# healthcheck.sh - Container health monitoring
# Provides health status checks for PostgreSQL and related services

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh
source /opt/container/entrypoint.d/scripts/utils/pgbouncer.sh

# Exit codes for health checks
HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

DATABASE_NAME="${CITUS_DATABASE:-${POSTGRES_DB:-postgres}}"

is_citus_enabled() {
    local flag="${CITUS_ENABLE:-false}"
    [[ "${flag,,}" == "true" ]]
}

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
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        if ! check_patroni_status; then
            overall_status=$HEALTH_CRITICAL
            issues+=("patroni_status")
        fi
    fi

    # Check PgBouncer status if enabled
    if [ "${PGBOUNCER_ENABLE:-false}" = "true" ]; then
        if ! check_pgbouncer_status; then
            overall_status=$HEALTH_CRITICAL
            issues+=("pgbouncer_status")
        else
            # Check for configuration changes and reload if needed
            reload_pgbouncer_config || true
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

    # Check Citus status when enabled
    if is_citus_enabled; then
        if ! check_citus_status; then
            overall_status=$HEALTH_CRITICAL
            issues+=("citus_status")
        fi
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

# Check PgBouncer status
check_pgbouncer_status() {
    log_debug "Checking PgBouncer status"

    # Check if PgBouncer is running
    if ! pgrep -f "pgbouncer" >/dev/null 2>&1; then
        log_error "PgBouncer process is not running"
        return 1
    fi

    local pgbouncer_port="${PGBOUNCER_PORT:-6432}"
    local pgbouncer_host="${PGBOUNCER_HOST:-localhost}"

    # Try to connect to PgBouncer admin interface
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    if echo "SHOW POOLS;" | psql -h "$pgbouncer_host" -p "$pgbouncer_port" -U "$POSTGRES_USER" -d pgbouncer >/dev/null 2>&1; then
        log_debug "PgBouncer is accepting connections"
        return 0
    else
        log_error "PgBouncer is not accepting connections"
        return 1
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
    mount_point=$(df -P "$data_dir" | tail -1 | awk '{print $6}')

    local df_usage df_usage_mb used_percent free_percent free_mb
    df_usage=$(df -P "$mount_point" | tail -1)
    used_percent=$(awk '{print $5}' <<<"$df_usage" | tr -d '%')
    free_percent=$((100 - used_percent))

    df_usage_mb=$(df -Pm "$mount_point" | tail -1)
    free_mb=$(awk '{print $4}' <<<"$df_usage_mb")

    log_debug "Disk space check: ${free_percent}% free, ${free_mb}MB free on $mount_point"

    # Check thresholds (fail only if both free percentage and free space fall below limits)
    if [ "$free_percent" -lt "$min_free_percent" ] && [ "$free_mb" -lt "$min_free_mb" ]; then
        log_error "Low disk space: ${free_percent}% free, ${free_mb}MB free"
        return 1
    fi

    return 0
}

# Check process health
check_process_health() {
    log_debug "Checking process health"


# Check Citus extension health
check_citus_status() {
    log_debug "Checking Citus extension status"

    if ! command -v psql >/dev/null 2>&1; then
        log_warn "psql not available; skipping Citus health check"
        return 0
    fi

    local extension_count
    extension_count=$(su - postgres -c "psql -v ON_ERROR_STOP=1 -tA --dbname '${DATABASE_NAME}' --command \"SELECT COUNT(*) FROM pg_extension WHERE extname = 'citus';\"" 2>/dev/null || echo "0")

    if ! [[ "${extension_count}" =~ ^[0-9]+$ ]]; then
        log_error "Unable to determine Citus extension state"
        return 1
    fi

    if [ "${extension_count}" -eq 0 ]; then
        log_error "Citus extension is not installed in database ${DATABASE_NAME}"
        return 1
    fi

    if ! su - postgres -c "psql -v ON_ERROR_STOP=1 --dbname '${DATABASE_NAME}' --command \"SELECT citus_version();\"" >/dev/null 2>&1; then
        log_error "Failed to query citus_version()"
        return 1
    fi

    local role="${CITUS_ROLE:-coordinator}"
    local is_coord
    is_coord=$(su - postgres -c "psql -v ON_ERROR_STOP=1 -tA --dbname '${DATABASE_NAME}' --command \"SELECT CASE WHEN citus_is_coordinator() THEN 1 ELSE 0 END;\"" 2>/dev/null || echo "-1")

    if [[ "${role}" == "coordinator" && "${is_coord}" != "1" ]]; then
        log_error "Node expected to act as coordinator but citus_is_coordinator() returned ${is_coord}"
        return 1
    fi

    if [[ "${role}" == "worker" && "${is_coord}" != "0" ]]; then
        log_error "Node expected to act as worker but citus_is_coordinator() returned ${is_coord}"
        return 1
    fi

    log_debug "Citus health check passed"
    return 0
}
    # Check for PostgreSQL processes
    local pg_processes
    pg_processes=$(pgrep -f "postgres" | wc -l)

    if [ "$pg_processes" -eq 0 ]; then
        # If Patroni is enabled, PostgreSQL might not be running directly
        if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
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
    memory_usage=$(ps -C postgres -o pmem= 2>/dev/null | awk '{sum+=$1} END {if (NR==0) print 0; else print sum}')
    memory_usage=${memory_usage:-0}

    if awk "BEGIN { exit !($memory_usage > 90) }" 2>/dev/null; then
        log_error "High memory usage by PostgreSQL processes: ${memory_usage}%"
        return 1
    fi

    return 0
}

# Execute main function with arguments
main "$@"