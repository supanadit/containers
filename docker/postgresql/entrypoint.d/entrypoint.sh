#!/bin/bash
# entrypoint.sh - Main container orchestrator
# Coordinates all modular scripts for PostgreSQL container initialization and runtime

# Set strict error handling
set -euo pipefail

# Source all utility functions first
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Script version
SCRIPT_VERSION="1.0.0"

# Default directories
export DEFAULT_PGDATA="${DEFAULT_PGDATA:-/usr/local/pgsql/data}"
export DEFAULT_PGCONFIG="${DEFAULT_PGCONFIG:-/usr/local/pgsql/config}"
export DEFAULT_PGLOG="${DEFAULT_PGLOG:-/usr/local/pgsql/log}"
export DEFAULT_PGRUN="${DEFAULT_PGRUN:-/tmp}"
export DEFAULT_PGBACKUP="${DEFAULT_PGBACKUP:-/usr/local/pgsql/backup}"

# Set actual variables used by scripts
export PGDATA="$DEFAULT_PGDATA"
export PGCONFIG="$DEFAULT_PGCONFIG"
export PGLOG="$DEFAULT_PGLOG"
export PGRUN="$DEFAULT_PGRUN"
export PGBACKUP="$DEFAULT_PGBACKUP"

export POSTGRES_USER="${POSTGRES_USER:-postgres}"
export POSTGRES_DB="${POSTGRES_DB:-postgres}"
export POSTGRES_INITDB_ARGS="${POSTGRES_INITDB_ARGS:-}"
export POSTGRES_INITDB_WALDIR="${POSTGRES_INITDB_WALDIR:-}"
export POSTGRES_HOST_AUTH_METHOD="${POSTGRES_HOST_AUTH_METHOD:-trust}"

# Citus configuration environment variables
export CITUS_ROLE="${CITUS_ROLE:-coordinator}"
export CITUS_NODE_NAME="${CITUS_NODE_NAME:-}"
export CITUS_BACKUP_SCOPE="${CITUS_BACKUP_SCOPE:-coordinator-only}"

citus_enable_raw="${CITUS_ENABLE:-false}"
case "${citus_enable_raw,,}" in
    true|1|yes|on)
        CITUS_ENABLE="true"
        if [ -z "${CITUS_GROUP:-}" ]; then
            if [ "${CITUS_ROLE}" = "worker" ]; then
                CITUS_GROUP=1
            else
                CITUS_GROUP=0
            fi
        fi
        export CITUS_GROUP
        export CITUS_DATABASE="${CITUS_DATABASE:-citus}"
        ;;
    *)
        CITUS_ENABLE="false"
        unset CITUS_GROUP
        if [ -n "${CITUS_DATABASE:-}" ]; then
            export CITUS_DATABASE
        else
            unset CITUS_DATABASE
        fi
        ;;
esac
export CITUS_ENABLE

# PgBouncer configuration environment variables
pgbouncer_enable_raw="${PGBOUNCER_ENABLE:-false}"
case "${pgbouncer_enable_raw,,}" in
    true|1|yes|on)
        PGBOUNCER_ENABLE="true"
        ;;
    *)
        PGBOUNCER_ENABLE="false"
        ;;
esac
export PGBOUNCER_ENABLE

# PgBouncer runtime configuration environment variables
export PGBOUNCER_LISTEN_ADDR="${PGBOUNCER_LISTEN_ADDR:-0.0.0.0}"
export PGBOUNCER_LISTEN_PORT="${PGBOUNCER_LISTEN_PORT:-6432}"
export PGBOUNCER_AUTH_TYPE="${PGBOUNCER_AUTH_TYPE:-md5}"
export PGBOUNCER_ADMIN_USERS="${PGBOUNCER_ADMIN_USERS:-postgres}"
export PGBOUNCER_STATS_USERS="${PGBOUNCER_STATS_USERS:-postgres}"
export PGBOUNCER_POOL_MODE="${PGBOUNCER_POOL_MODE:-transaction}"
export PGBOUNCER_MAX_CLIENT_CONN="${PGBOUNCER_MAX_CLIENT_CONN:-100}"
export PGBOUNCER_DEFAULT_POOL_SIZE="${PGBOUNCER_DEFAULT_POOL_SIZE:-20}"

# Timezone configuration
export POSTGRESQL_TIMEZONE="${POSTGRESQL_TIMEZONE:-UTC}"
export PGBACKREST_AUTO_TIMEZONE="${PGBACKREST_AUTO_TIMEZONE:-UTC}"

# Main function
main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"

    # Log startup information
    log_info "PostgreSQL Container Entrypoint v$SCRIPT_VERSION"
    log_environment

    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi

    # Validate dependencies
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi

    # Set up signal handlers
    setup_signal_handlers

    # Run initialization scripts in order
    run_initialization

    # Start runtime management
    start_runtime

    log_script_end "entrypoint.sh"
}

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    log_debug "Setting up signal handlers"

    # Handle common termination signals
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP

    log_debug "Signal handlers configured"
}

# Handle shutdown signals
handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"

    # Run shutdown script
    if [ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi

    log_info "Shutdown complete"
    exit 0
}

# Run initialization scripts in order
run_initialization() {
    log_info "Running initialization scripts"

    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/01-directories.sh"
        "/opt/container/entrypoint.d/scripts/init/02-database.sh"
        "/opt/container/entrypoint.d/scripts/init/03-config.sh"
        "/opt/container/entrypoint.d/scripts/init/04-backup.sh"
    )

    for script in "${init_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Running initialization script: $(basename "$script")"
            if ! "$script"; then
                log_error "Initialization script failed: $(basename "$script")"
                exit 1
            fi
        else
            log_warn "Initialization script not found or not executable: $script"
        fi
    done

    log_info "All initialization scripts completed successfully"
}

# Start runtime management
start_runtime() {
    log_info "Starting runtime management"

    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"

    if [ -f "$startup_script" ] && [ -x "$startup_script" ]; then
        log_info "Starting PostgreSQL via startup script"
        exec "$startup_script"
    else
        log_error "Startup script not found or not executable: $startup_script"
        exit 1
    fi
}

# Execute main function
main "$@"