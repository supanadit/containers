#!/bin/bash
# citus.sh - Runtime initialization and cluster coordination for Citus

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

DATABASE_NAME="${CITUS_DATABASE:-${POSTGRES_DB:-postgres}}"
DEFAULT_WORKER_PORT="${CITUS_DEFAULT_WORKER_PORT:-5432}"
COORDINATOR_USER="${CITUS_COORDINATOR_USER:-${POSTGRES_USER:-postgres}}"
COORDINATOR_PASSWORD="${CITUS_COORDINATOR_PASSWORD:-${POSTGRES_PASSWORD:-}}"
ADVERTISE_HOST="${CITUS_ADVERTISE_HOST:-}"
ADVERTISE_PORT="${CITUS_ADVERTISE_PORT:-${POSTGRESQL_PORT:-5432}}"
AUTO_REGISTER="${CITUS_AUTO_REGISTER:-true}"
AUTO_REBALANCE="${CITUS_AUTO_REBALANCE:-false}"
COORDINATOR_LOCK_KEY=543212
WORKER_LOCK_KEY=543213

is_citus_enabled() {
    local flag="${CITUS_ENABLE:-false}"
    [[ "${flag,,}" == "true" ]]
}

psql_superuser() {
    local sql="$1"
    su - postgres -c "PATH=/usr/local/pgsql/bin:$PATH psql -v ON_ERROR_STOP=1 --dbname \"${DATABASE_NAME}\" --command \"${sql}\"" >/dev/null
}

psql_superuser_output() {
    local sql="$1"
    su - postgres -c "PATH=/usr/local/pgsql/bin:$PATH psql -v ON_ERROR_STOP=1 -tA --dbname \"${DATABASE_NAME}\" --command \"${sql}\"" 2>/dev/null
}

is_primary() {
    local result
    result=$(psql_superuser_output "SELECT CASE WHEN pg_is_in_recovery() THEN 0 ELSE 1 END;")
    [[ "${result}" == "1" ]]
}

with_coordination_lock() {
    local lock_key="$1"
    local action="$2"

    if ! su - postgres -c "PATH=/usr/local/pgsql/bin:$PATH psql -v ON_ERROR_STOP=1 --dbname \"${DATABASE_NAME}\" --command \"SELECT pg_advisory_lock(${lock_key});\"" >/dev/null; then
        log_error "Failed to acquire advisory lock ${lock_key} for ${action}"
        return 1
    fi

    local status=0
    if ! eval "$action"; then
        status=$?
    fi

    su - postgres -c "PATH=/usr/local/pgsql/bin:$PATH psql -v ON_ERROR_STOP=1 --dbname \"${DATABASE_NAME}\" --command \"SELECT pg_advisory_unlock(${lock_key});\"" >/dev/null || true
    return $status
}

determine_node_identity() {
    local host="$1"
    local port="$2"

    if [ -n "$host" ]; then
        echo "$host"
        return 0
    fi

    if command -v hostname >/dev/null 2>&1; then
        hostname -f || hostname
        return 0
    fi

    echo "localhost"
}

create_extension_if_needed() {
    log_debug "Ensuring Citus extension exists in ${DATABASE_NAME}"
    psql_superuser "CREATE EXTENSION IF NOT EXISTS citus;"
}

sanitize_endpoint() {
    local endpoint="$1"
    [[ "$endpoint" =~ ^[A-Za-z0-9_.-]+(:[0-9]+)?$ ]]
}

worker_exists() {
    local host="$1"
    local port="$2"
    local result
    result=$(psql_superuser_output "SELECT 1 FROM pg_dist_node WHERE nodename='${host}' AND nodeport=${port} LIMIT 1;")
    [[ "${result}" == "1" ]]
}

add_worker_node() {
    local host="$1"
    local port="$2"

    if worker_exists "$host" "$port"; then
        log_info "Worker node ${host}:${port} already registered"
        return 0
    fi

    log_info "Registering worker node ${host}:${port}"

    if [ -n "${COORDINATOR_PASSWORD}" ]; then
        local sanitized_pass
        sanitized_pass=$(printf "%s" "${COORDINATOR_PASSWORD}" | sed "s/'/''/g")
        psql_superuser "SELECT citus_add_node('${host}', ${port}, NULL, '${COORDINATOR_USER}', '${sanitized_pass}');"
        return 0
    fi

    psql_superuser "SELECT citus_add_node('${host}', ${port});"
}

configure_coordinator() {
    local worker_list="${CITUS_WORKER_NODES:-}${PATRONI_CITUS_WORKERS:+,${PATRONI_CITUS_WORKERS}}"

    if [ -n "${USE_PATRONI:-}" ] && [ "${USE_PATRONI}" = "true" ]; then
        export PATRONI_CITUS_ROLE="coordinator"
        local advertise
        advertise=$(determine_node_identity "$ADVERTISE_HOST" "$ADVERTISE_PORT")
        export PATRONI_CITUS_COORDINATOR_HOST="${advertise}"
        export PATRONI_CITUS_COORDINATOR_PORT="${ADVERTISE_PORT}"
    fi

    if [ -z "$worker_list" ]; then
        log_info "No worker nodes specified; skipping worker registration"
        return 0
    fi

    local register_workers_action='register_worker_nodes'
    with_coordination_lock "$COORDINATOR_LOCK_KEY" "$register_workers_action"
}

register_worker_nodes() {
    local all_workers="${CITUS_WORKER_NODES:-}${PATRONI_CITUS_WORKERS:+,${PATRONI_CITUS_WORKERS}}"
    IFS=',' read -ra workers <<< "$all_workers"

    for worker in "${workers[@]}"; do
        local trimmed_worker
        trimmed_worker=$(echo "$worker" | xargs)
        if [ -z "$trimmed_worker" ]; then
            continue
        fi

        if ! sanitize_endpoint "$trimmed_worker"; then
            log_warn "Skipping invalid worker endpoint: $trimmed_worker"
            continue
        fi

        local worker_host="$trimmed_worker"
        local worker_port="$DEFAULT_WORKER_PORT"

        if [[ "$trimmed_worker" == *":"* ]]; then
            worker_host="${trimmed_worker%%:*}"
            worker_port="${trimmed_worker##*:}"
        fi

        if ! [[ "$worker_port" =~ ^[0-9]+$ ]]; then
            log_warn "Skipping worker with invalid port: $trimmed_worker"
            continue
        fi

        add_worker_node "$worker_host" "$worker_port"
    done

    if [[ "${AUTO_REBALANCE,,}" == "true" ]]; then
        log_info "Triggering Citus rebalance for distributed tables"
        psql_superuser "SELECT rebalance_table_shards(table_name) FROM pg_dist_partition;"
    fi
}

configure_worker() {
    local coordinator_host="${CITUS_COORDINATOR_HOST:-}"
    local coordinator_port="${CITUS_COORDINATOR_PORT:-5432}"

    if [ -z "$coordinator_host" ]; then
        log_warn "CITUS_COORDINATOR_HOST not set; skipping worker configuration"
        return 0
    fi

    if ! [[ "$coordinator_port" =~ ^[0-9]+$ ]]; then
        log_warn "Invalid CITUS_COORDINATOR_PORT value: $coordinator_port"
        return 0
    fi

    log_info "Configuring worker to use coordinator ${coordinator_host}:${coordinator_port}"
    psql_superuser "SELECT citus_set_coordinator_host('${coordinator_host}', ${coordinator_port});"

    if [[ "${AUTO_REGISTER,,}" == "true" ]]; then
        auto_register_worker "$coordinator_host" "$coordinator_port"
    fi
}

auto_register_worker() {
    local coordinator_host="$1"
    local coordinator_port="$2"

    local worker_host
    worker_host=$(determine_node_identity "$ADVERTISE_HOST" "$ADVERTISE_PORT")
    local worker_port="$ADVERTISE_PORT"

    log_info "Self-registering worker as ${worker_host}:${worker_port} with coordinator"

    local register_action='register_self_with_coordinator'
    with_coordination_lock "$WORKER_LOCK_KEY" "$register_action"
}

register_self_with_coordinator() {
    local worker_host
    worker_host=$(determine_node_identity "$ADVERTISE_HOST" "$ADVERTISE_PORT")
    local worker_port="$ADVERTISE_PORT"

    if worker_exists "$worker_host" "$worker_port"; then
        log_debug "Worker ${worker_host}:${worker_port} already registered"
        return 0
    fi

    add_worker_node "$worker_host" "$worker_port"
}

main() {
    log_script_start "citus.sh"

    if ! is_citus_enabled; then
        log_debug "Citus is disabled; skipping initialization"
        log_script_end "citus.sh"
        return 0
    fi

    if ! is_primary && [ "${USE_PATRONI:-false}" = "true" ]; then
        log_info "Node is not primary under Patroni; skipping Citus bootstrap"
        log_script_end "citus.sh"
        return 0
    fi

    create_extension_if_needed

    local role="${CITUS_ROLE:-coordinator}"
    case "$role" in
        "coordinator")
            configure_coordinator
            ;;
        "worker")
            configure_worker
            ;;
        *)
            log_warn "Unknown CITUS_ROLE '$role'; no role-specific configuration applied"
            ;;
    esac

    log_script_end "citus.sh"
}

main "$@"
