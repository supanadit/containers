#!/bin/bash
# startup.sh - PostgreSQL process startup logic
# Handles startup of PostgreSQL or Patroni based on configuration

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    log_debug "Setting up signal handlers in startup script"

    # Handle common termination signals
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP

    log_debug "Signal handlers configured in startup script"
}

# Handle shutdown signals
handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal in startup script: $signal"

    # Run shutdown script
    if [ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi

    # Exit with success
    exit 0
}

# Main function
main() {
    log_script_start "startup.sh"

    # Set up signal handlers for graceful shutdown
    setup_signal_handlers

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

    # For Docker containers, run PostgreSQL in foreground mode
    log_info "Running PostgreSQL in foreground mode for container"

    # Prepare postgres command (not pg_ctl)
    local postgres_cmd="postgres"
    local postgres_args=("-D" "$data_dir")

    # Add config file if specified
    if [ -n "${POSTGRESQL_CONFIG_FILE:-}" ]; then
        postgres_args+=("-c" "config_file=${POSTGRESQL_CONFIG_FILE}")
    fi

    log_info "Starting PostgreSQL with command: $postgres_cmd ${postgres_args[*]}"

    # Start PostgreSQL as a background process (not exec, so we can handle signals)
    su -c "$postgres_cmd ${postgres_args[*]}" postgres &
    local pg_pid=$!

    log_info "PostgreSQL started with PID: $pg_pid"

    # Wait for PostgreSQL to be ready
    wait_for_postgresql_ready

    # Create replication user if in native HA primary mode
    if [[ "${HA_MODE:-}" == "native" && "${REPLICATION_ROLE:-}" == "primary" ]]; then
        create_replication_user
    fi

    # Initialize pgBackRest stanza if backup is enabled
    if [ "${BACKUP_ENABLED:-false}" = "true" ]; then
        initialize_pgbackrest_stanza
    fi

    # Log successful startup
    log_info "PostgreSQL is ready and accepting connections"

    # Wait for the PostgreSQL process to exit (or for shutdown signal)
    log_info "Waiting for PostgreSQL process to complete"
    wait $pg_pid

    local exit_code=$?
    log_info "PostgreSQL process exited with code: $exit_code"
    return $exit_code
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

    # Start Patroni as a background process (not exec, so we can handle signals)
    "$patroni_cmd" "${patroni_args[@]}" &
    local patroni_pid=$!

    log_info "Patroni started with PID: $patroni_pid"

    # Wait for Patroni to be ready (it will start PostgreSQL)
    wait_for_postgresql_ready

    # Initialize pgBackRest stanza if backup is enabled
    if [ "${BACKUP_ENABLED:-false}" = "true" ]; then
        initialize_pgbackrest_stanza
    fi

    # Log successful startup
    log_info "Patroni and PostgreSQL are ready"

    # Wait for the Patroni process to exit (or for shutdown signal)
    log_info "Waiting for Patroni process to complete"
    wait $patroni_pid

    local exit_code=$?
    log_info "Patroni process exited with code: $exit_code"
    return $exit_code
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

# Initialize pgBackRest stanza
initialize_pgbackrest_stanza() {
    log_info "Initializing pgBackRest stanza"

    local stanza="${PGBACKREST_STANZA:-default}"
    local backup_info_file="/usr/local/pgsql/backup/backup/${stanza}/backup.info"

    # Check if stanza backup info already exists
    if [ -f "$backup_info_file" ]; then
        log_info "pgBackRest stanza '$stanza' backup info already exists"
        return 0
    fi

    # Create the stanza as postgres user
    log_info "Creating pgBackRest stanza: $stanza"
    if ! su -c "pgbackrest --stanza=\"$stanza\" stanza-create" postgres; then
        log_error "Failed to create pgBackRest stanza: $stanza"
        return 1
    fi

    log_info "Successfully created pgBackRest stanza: $stanza"
}

# Create replication user for native HA
create_replication_user() {
    log_info "Creating replication user for native HA"
    
    # Wait a moment for PostgreSQL to be fully ready
    sleep 2

    if [[ -z "${REPLICATION_PASSWORD:-}" ]]; then
        log_error "REPLICATION_PASSWORD must be set when HA_MODE=native and REPLICATION_ROLE=primary"
        return 1
    fi

    local role_name="${REPLICATION_USER:-replicator}"
    local escaped_role_name="${role_name//\'/''}"
    local escaped_password="${REPLICATION_PASSWORD//\'/''}"

    local sql
    printf -v sql "SET password_encryption = 'scram-sha-256'; DO \$do\$ BEGIN BEGIN EXECUTE format('ALTER ROLE %%I WITH LOGIN REPLICATION PASSWORD %%L', '%s', '%s'); EXCEPTION WHEN UNDEFINED_OBJECT THEN EXECUTE format('CREATE ROLE %%I WITH LOGIN REPLICATION PASSWORD %%L', '%s', '%s'); END; END; \$do\$;" "$escaped_role_name" "$escaped_password" "$escaped_role_name" "$escaped_password"

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --command "$sql"
    
    log_info "Replication user created successfully"
}

# Execute main function
main "$@"