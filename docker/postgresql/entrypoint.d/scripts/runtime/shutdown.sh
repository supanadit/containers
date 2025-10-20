#!/bin/bash
# shutdown.sh - Graceful PostgreSQL shutdown handling
# Manages shutdown process with timeout and cleanup

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Default shutdown timeout (30 seconds as per requirements)
DEFAULT_SHUTDOWN_TIMEOUT=30

# Main function
main() {
    log_script_start "shutdown.sh"

    # Get shutdown timeout
    local timeout="${TIMEOUT:-$DEFAULT_SHUTDOWN_TIMEOUT}"

    log_info "Initiating graceful shutdown (timeout: ${timeout}s)"

    # Initiate graceful shutdown
    initiate_graceful_shutdown "$timeout"

    # Wait for shutdown to complete
    wait_for_shutdown "$timeout"

    # Force shutdown if graceful failed
    force_shutdown_if_needed

    # Cleanup resources
    cleanup_resources

    log_script_end "shutdown.sh"
}

# Initiate graceful shutdown
initiate_graceful_shutdown() {
    local timeout="$1"

    log_info "Sending SIGTERM to PostgreSQL processes"

    # Find PostgreSQL processes
    local pg_pids
    pg_pids=$(pgrep -f "postgres" || true)

    if [ -z "$pg_pids" ]; then
        log_info "No PostgreSQL processes found"
        return 0
    fi

    # Send SIGTERM to all PostgreSQL processes
    echo "$pg_pids" | while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_debug "Sending SIGTERM to PostgreSQL process: $pid"
            kill -TERM "$pid" || true
        fi
    done

    # Also try Patroni if it might be running
    local patroni_pids
    patroni_pids=$(pgrep -f "patroni" || true)

    if [ -n "$patroni_pids" ]; then
        echo "$patroni_pids" | while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_debug "Sending SIGTERM to Patroni process: $pid"
                kill -TERM "$pid" || true
            fi
        done
    fi

    # Also try PgBouncer if it might be running
    if [ "${PGBOUNCER_ENABLE:-false}" = "true" ]; then
        local pgbouncer_pids
        pgbouncer_pids=$(pgrep -f "pgbouncer" || true)

        if [ -n "$pgbouncer_pids" ]; then
            echo "$pgbouncer_pids" | while read -r pid; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    log_debug "Sending SIGTERM to PgBouncer process: $pid"
                    kill -TERM "$pid" || true
                fi
            done
        fi
    fi
}

# Wait for shutdown to complete
wait_for_shutdown() {
    local timeout="$1"
    local start_time
    start_time=$(date +%s)

    log_debug "Waiting for processes to shutdown (timeout: ${timeout}s)"

    while true; do
        # Check if we're over time
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $timeout ]; then
            log_warn "Shutdown timeout reached (${timeout}s)"
            return 1
        fi

        # Check for remaining PostgreSQL processes
        if ! pgrep -f "postgres" >/dev/null 2>&1; then
            # Check for Patroni processes
            if ! pgrep -f "patroni" >/dev/null 2>&1; then
                # Check for PgBouncer processes if enabled
                if [ "${PGBOUNCER_ENABLE:-false}" != "true" ] || ! pgrep -f "pgbouncer" >/dev/null 2>&1; then
                    log_info "All processes have shut down gracefully"
                    return 0
                fi
            fi
        fi

        # Wait a bit before checking again
        sleep 1
    done
}

# Force shutdown if graceful failed
force_shutdown_if_needed() {
    log_warn "Forcing shutdown of remaining processes"

    # Find any remaining PostgreSQL processes
    local remaining_pids
    remaining_pids=$(pgrep -f "postgres" || true)

    if [ -n "$remaining_pids" ]; then
        log_warn "Sending SIGKILL to remaining PostgreSQL processes"
        echo "$remaining_pids" | while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_error "Force killing PostgreSQL process: $pid"
                kill -KILL "$pid" || true
            fi
        done
    fi

    # Find any remaining Patroni processes
    remaining_pids=$(pgrep -f "patroni" || true)

    if [ -n "$remaining_pids" ]; then
        log_warn "Sending SIGKILL to remaining Patroni processes"
        echo "$remaining_pids" | while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_error "Force killing Patroni process: $pid"
                kill -KILL "$pid" || true
            fi
        done
    fi

    # Find any remaining PgBouncer processes
    if [ "${PGBOUNCER_ENABLE:-false}" = "true" ]; then
        remaining_pids=$(pgrep -f "pgbouncer" || true)

        if [ -n "$remaining_pids" ]; then
            log_warn "Sending SIGKILL to remaining PgBouncer processes"
            echo "$remaining_pids" | while read -r pid; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    log_error "Force killing PgBouncer process: $pid"
                    kill -KILL "$pid" || true
                fi
            done
        fi
    fi

    # Log final cleanup
    log_info "Resource cleanup completed"
}

# Clean up PID files
cleanup_pid_files() {
    local run_dir="${PGRUN:-/usr/local/pgsql/run}"

    log_debug "Cleaning up PID files in: $run_dir"

    # Remove PostgreSQL PID file
    local pid_file="$run_dir/postmaster.pid"
    if [ -f "$pid_file" ]; then
        rm -f "$pid_file"
        log_debug "Removed PID file: $pid_file"
    fi

    # Remove sleep mode PID file
    local sleep_pid_file="$run_dir/sleep.pid"
    if [ -f "$sleep_pid_file" ]; then
        rm -f "$sleep_pid_file"
        log_debug "Removed sleep PID file: $sleep_pid_file"
    fi
}

# Clean up socket files
cleanup_socket_files() {
    local run_dir="${PGRUN:-/usr/local/pgsql/run}"

    log_debug "Cleaning up socket files in: $run_dir"

    # Remove PostgreSQL socket files
    local socket_pattern="$run_dir/.s.PGSQL.*"
    if compgen -G "$socket_pattern" >/dev/null 2>&1; then
        rm -f $socket_pattern
        log_debug "Removed PostgreSQL socket files"
    fi
}

# Clean up temporary files
cleanup_temp_files() {
    log_debug "Cleaning up temporary files"

    # Clean up any temporary files created during operation
    # This is mainly for any files created by the scripts themselves

    # Clean up pgpass file if it exists
    if [ -f "/tmp/pgpass" ]; then
        secure_cleanup "/tmp/pgpass"
        log_debug "Cleaned up pgpass file"
    fi

    # Clean up any other temporary files that might exist
    # (This is a general cleanup - specific files would be handled by their creators)
}

# Execute main function
main "$@"