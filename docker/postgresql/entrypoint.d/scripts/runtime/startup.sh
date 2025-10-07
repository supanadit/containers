#!/bin/bash
# startup.sh - PostgreSQL process startup logic
# Handles startup of PostgreSQL or Patroni based on configuration

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh
source /opt/container/entrypoint.d/scripts/utils/cluster.sh

# Helper function to generate env command that removes all PGBACKREST environment variables
generate_clean_env_command() {
    local env_cmd="env"
    
    # Get all PGBACKREST_* environment variables and add them to the unset list
    while IFS='=' read -r var_name var_value; do
        if [[ "$var_name" =~ ^PGBACKREST_ ]]; then
            env_cmd="$env_cmd -u $var_name"
        fi
    done < <(env | grep '^PGBACKREST_')
    
    echo "$env_cmd"
}

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
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
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
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ]; then
        initialize_pgbackrest_stanza
        if [ "${PGBACKREST_AUTO_ENABLE:-false}" = "true" ]; then
            start_pgbackrest_scheduler "$pg_pid"
        fi
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
    su -c "$patroni_cmd ${patroni_args[*]}" postgres &
    local patroni_pid=$!

    log_info "Patroni started with PID: $patroni_pid"

    # Wait for Patroni to be ready (it will start PostgreSQL)
    wait_for_postgresql_ready

    # Initialize pgBackRest stanza if backup is enabled
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ]; then
        initialize_pgbackrest_stanza
        if [ "${PGBACKREST_AUTO_ENABLE:-false}" = "true" ]; then
            # Patroni main process is patroni_pid; pass it
            start_pgbackrest_scheduler "$patroni_pid"
        fi
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
    local backup_dir="${PGBACKUP:-/usr/local/pgsql/backup}"
    local archive_info_file="$backup_dir/archive/$stanza/archive.info"
    local backup_info_file="$backup_dir/backup/$stanza/backup.info"
    local repo_type="${PGBACKREST_REPO_TYPE:-posix}"

    if [ "${PGBACKREST_STANZA_CREATE_ON_PRIMARY_ONLY:-true}" = "true" ]; then
        if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
            local wait_target=$(( ${PGBACKREST_STANZA_PRIMARY_WAIT:-60} ))
            local waited=0
            local primary_ready=false
            while [ $waited -lt "$wait_target" ]; do
                if is_primary_role; then
                    primary_ready=true
                    break
                fi
                sleep 2
                waited=$((waited + 2))
            done
            if [ "$primary_ready" != "true" ]; then
                log_info "Skipping pgBackRest stanza creation; node not Patroni leader after ${wait_target}s"
                return 0
            fi
        elif ! is_primary_role; then
            log_info "Skipping pgBackRest stanza creation because node is not primary"
            return 0
        fi
    fi

    if ! is_citus_backup_allowed; then
        log_info "Skipping pgBackRest stanza creation for Citus role ${CITUS_ROLE:-unknown}"
        return 0
    fi

    # For posix/filesystem repositories, we can detect stanza by local files; for remote/object repos (s3/gcs) skip
    if [ "$repo_type" = "posix" ] || [ "$repo_type" = "filesystem" ]; then
        if [ -f "$archive_info_file" ] && [ -f "$backup_info_file" ]; then
            log_info "pgBackRest stanza '$stanza' already exists (local files detected)"
            return 0
        fi
    else
        log_debug "Skipping local stanza existence check for repo1-type=${repo_type}"
    fi

    # Create the stanza as postgres user (unset problematic environment variables)
    local clean_env_cmd
    clean_env_cmd="$(generate_clean_env_command)"
    log_info "Creating pgBackRest stanza: $stanza"
    if ! su -c "$clean_env_cmd pgbackrest --config=/etc/pgbackrest.conf --stanza=\"$stanza\" stanza-create" postgres; then
        local exit_code=$?
        log_warn "Initial stanza-create failed (exit code: $exit_code), checking if stanza upgrade is needed"
        
        # Try stanza-upgrade to handle existing backup files
        log_info "Attempting stanza upgrade to handle existing backup files"
        if ! su -c "$clean_env_cmd pgbackrest --config=/etc/pgbackrest.conf --stanza=\"$stanza\" stanza-upgrade" postgres; then
            log_error "Both stanza-create and stanza-upgrade failed for stanza: $stanza"
            log_info "This may indicate:"
            log_info "  1. S3 connectivity issues"
            log_info "  2. Permission problems with S3 bucket"
            log_info "  3. Incompatible backup files in repository"
            log_info "  4. Database system identifier mismatch"
            log_info "To resolve manually:"
            log_info "  - Check S3 credentials and connectivity"
            log_info "  - Clear the S3 bucket if safe to do so"
            log_info "  - Run 'pgbackrest --stanza=$stanza info' for diagnostics"
            return 1
        else
            log_info "Successfully upgraded pgBackRest stanza: $stanza"
        fi
    else
        log_info "Successfully created pgBackRest stanza: $stanza"
    fi
}

# Launch pgBackRest automatic backup scheduler (non-blocking)
start_pgbackrest_scheduler() {
    local parent_pid="$1"
    if [ ! -x /opt/container/entrypoint.d/scripts/runtime/backup-scheduler.sh ]; then
        log_error "Backup scheduler script missing or not executable"
        return 1
    fi
    log_info "Starting pgBackRest automatic backup scheduler"
    PGBACKREST_PARENT_PID="$parent_pid" nohup /opt/container/entrypoint.d/scripts/runtime/backup-scheduler.sh >/var/log/pgbackrest-auto.log 2>&1 &
    local sched_pid=$!
    log_info "pgBackRest backup scheduler started with PID ${sched_pid} (log: /var/log/pgbackrest-auto.log)"
}
export -f start_pgbackrest_scheduler

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