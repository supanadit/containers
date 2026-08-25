#!/bin/bash
# healthcheck.sh - Container health monitoring for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

main() {
    local check_type="${1:-comprehensive}"

    case "$check_type" in
        mariadb)
            check_mariadb_connectivity
            ;;
        galera)
            check_galera_status
            ;;
        disk)
            check_disk_space
            ;;
        process)
            check_process_health
            ;;
        comprehensive|*)
            comprehensive_health_check
            ;;
    esac
}

comprehensive_health_check() {
    local overall_status=$HEALTH_OK
    local issues=()

    log_debug "Running comprehensive health check"

    if ! check_mariadb_connectivity; then
        overall_status=$HEALTH_CRITICAL
        issues+=("mariadb_connectivity")
    fi

    if [ "${MARIADB_GALERA_ENABLE:-false}" = "true" ]; then
        if ! check_galera_status; then
            overall_status=$HEALTH_CRITICAL
            issues+=("galera_status")
        fi
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

check_mariadb_connectivity() {
    log_debug "Checking MariaDB connectivity"

    if mariadb -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "SELECT 1" >/dev/null 2>&1; then
        log_debug "MariaDB is accepting connections"
        return 0
    else
        log_error "MariaDB is not accepting connections"
        return 1
    fi
}

check_galera_status() {
    log_debug "Checking Galera cluster status"

    local wsrep_status
    wsrep_status=$(mariadb -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "SHOW STATUS LIKE 'wsrep_cluster_status';" 2>/dev/null | tail -1 | awk '{print $2}')

    if [ "$wsrep_status" = "Primary" ]; then
        log_debug "Galera node is connected to primary cluster"
        return 0
    else
        log_error "Galera node is not connected to primary cluster (status: $wsrep_status)"
        return 1
    fi
}

check_disk_space() {
    log_debug "Checking disk space"

    local data_dir="${MARIADB_DATA_DIR:-/opt/containers/data}"
    local mount_point
    mount_point=$(df -P "$data_dir" | tail -1 | awk '{print $6}')

    local df_usage
    df_usage=$(df -P "$mount_point" | tail -1 | awk '{print $5}' | tr -d '%')

    log_debug "Disk usage: ${df_usage}%"

    if [ "$df_usage" -gt 90 ]; then
        log_error "Low disk space: ${df_usage}% used"
        return 1
    fi

    return 0
}

check_process_health() {
    log_debug "Checking process health"

    local mariadb_processes
    mariadb_processes=$(pgrep -f "mariadbd" | wc -l)

    if [ "$mariadb_processes" -eq 0 ]; then
        log_error "No MariaDB processes found"
        return 1
    fi

    log_debug "Found $mariadb_processes MariaDB process(es)"
    return 0
}

main "$@"