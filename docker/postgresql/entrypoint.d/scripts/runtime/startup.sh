#!/bin/bash
# startup.sh - PostgreSQL process startup logic
# Handles startup of PostgreSQL or Patroni based on configuration

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Main function
main() {
    log_script_start "startup.sh"

    # Validate environment before proceeding
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    # Validate security context
    if ! validate_security_context; then
        log_error "Security context validation failed"
        return 1
    fi

    # Select startup mode
    select_startup_mode

    log_script_end "startup.sh"
}

# Select the appropriate startup mode
select_startup_mode() {
    log_info "Selecting startup mode"

    # Check for sleep mode (maintenance)
    if [ "${SLEEP_MODE:-false}" = "true" ]; then
        log_info "Sleep mode enabled, entering maintenance mode"
        start_sleep_mode
        return $?
    fi

    # Check for Patroni mode
    if [ "${USE_PATRONI:-false}" = "true" ]; then
        log_info "Patroni mode enabled, starting Patroni"
        start_patroni
        return $?
    fi

    # Default to direct PostgreSQL startup
    log_info "Starting PostgreSQL directly"
    start_postgresql_direct
    return $?
}

# Start PostgreSQL directly
start_postgresql_direct() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local config_file="$data_dir/postgresql.conf"

    log_info "Starting PostgreSQL directly"

    # Validate that data directory exists
    if [ ! -d "$data_dir" ]; then
        log_error "PostgreSQL data directory does not exist: $data_dir"
        return 1
    fi

    # Validate configuration
    if ! validate_postgresql_conf "$config_file"; then
        log_error "PostgreSQL configuration validation failed"
        return 1
    fi

    # Prepare startup command
    local pg_ctl_cmd="pg_ctl"
    local pg_ctl_args=("-D" "$data_dir" "-l" "${PGLOG:-/usr/local/pgsql/log}/postgresql.log")

    # Add wait option for synchronous startup
    pg_ctl_args+=("-w")

    # Add timeout
    local timeout="${TIMEOUT:-30}"
    pg_ctl_args+=("-t" "$timeout")

    log_debug "Starting PostgreSQL with command: $pg_ctl_cmd ${pg_ctl_args[*]}"

    # Start PostgreSQL as postgres user
    if su -c "$pg_ctl_cmd ${pg_ctl_args[*]} start" postgres; then
        log_info "PostgreSQL started successfully"

        # Wait for PostgreSQL to be ready
        wait_for_postgresql_ready

        # Log successful startup
        log_info "PostgreSQL is ready and accepting connections"
        return 0
    else
        log_error "Failed to start PostgreSQL"
        return 1
    fi
}

# Start Patroni
start_patroni() {
    log_info "Starting Patroni"

    # Validate Patroni configuration
    local patroni_config="/etc/patroni.yml"
    if [ ! -f "$patroni_config" ]; then
        log_error "Patroni configuration not found: $patroni_config"
        return 1
    fi

    if ! validate_patroni_config "$patroni_config"; then
        log_error "Patroni configuration validation failed"
        return 1
    fi

    # Prepare Patroni command
    local patroni_cmd="patroni"
    local patroni_args=("$patroni_config")

    log_debug "Starting Patroni with command: $patroni_cmd ${patroni_args[*]}"

    # Start Patroni (it will manage PostgreSQL)
    exec "$patroni_cmd" "${patroni_args[@]}"
}

# Start sleep mode (maintenance)
start_sleep_mode() {
    log_info "Entering sleep mode (maintenance)"

    # Log environment for debugging
    log_environment

    # Create a PID file to indicate we're running
    local pid_file="${PGRUN:-/usr/local/pgsql/run}/sleep.pid"
    echo $$ > "$pid_file"

    log_info "Container is in maintenance mode"
    log_info "Use 'docker exec' to access the container for maintenance tasks"

    # Sleep indefinitely
    while true; do
        sleep 3600
    done
}

# Wait for PostgreSQL to be ready
wait_for_postgresql_ready() {
    local max_attempts=30
    local attempt=1

    log_debug "Waiting for PostgreSQL to be ready"

    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h localhost -p "${POSTGRESQL_PORT:-5432}" -U "${POSTGRES_USER:-postgres}" >/dev/null 2>&1; then
            log_debug "PostgreSQL is ready (attempt $attempt)"
            return 0
        fi

        log_debug "PostgreSQL not ready yet (attempt $attempt/$max_attempts)"
        sleep 1
        ((attempt++))
    done

    log_error "PostgreSQL failed to become ready after $max_attempts attempts"
    return 1
}

# Execute main function
main "$@"