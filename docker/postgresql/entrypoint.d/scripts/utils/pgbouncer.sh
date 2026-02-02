#!/bin/bash
# pgbouncer.sh - PgBouncer management utilities
# Provides functions for managing PgBouncer configuration and runtime operations

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh

# Reload PgBouncer configuration if it has changed
reload_pgbouncer_config() {
    log_debug "Checking for PgBouncer configuration changes"

    # Ensure PgBouncer environment variables are set
    export PGBOUNCER_LISTEN_ADDR="${PGBOUNCER_LISTEN_ADDR:-0.0.0.0}"
    export PGBOUNCER_LISTEN_PORT="${PGBOUNCER_LISTEN_PORT:-6432}"
    export PGBOUNCER_AUTH_TYPE="${PGBOUNCER_AUTH_TYPE:-md5}"
    export PGBOUNCER_ADMIN_USERS="${PGBOUNCER_ADMIN_USERS:-postgres}"
    export PGBOUNCER_STATS_USERS="${PGBOUNCER_STATS_USERS:-postgres}"
    export PGBOUNCER_POOL_MODE="${PGBOUNCER_POOL_MODE:-transaction}"
    export PGBOUNCER_MAX_CLIENT_CONN="${PGBOUNCER_MAX_CLIENT_CONN:-100}"
    export PGBOUNCER_DEFAULT_POOL_SIZE="${PGBOUNCER_DEFAULT_POOL_SIZE:-20}"
    export IGNORE_STARTUP_PARAMETERS="${IGNORE_STARTUP_PARAMETERS}:-"

    # Check if PgBouncer is enabled and running
    if [ "${PGBOUNCER_ENABLE:-false}" != "true" ]; then
        return 0
    fi

    if ! pgrep -f "pgbouncer" >/dev/null 2>&1; then
        log_debug "PgBouncer is not running, skipping config reload check"
        return 0
    fi

    local config_file="/etc/pgbouncer/pgbouncer.ini"
    local processed_config_file="/etc/pgbouncer/pgbouncer-processed.ini"
    local config_hash_file="/etc/pgbouncer/config.hash"

    # Process current environment variables
    local temp_config_file
    temp_config_file=$(mktemp)
    cp "$config_file" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_LISTEN_ADDR}|${PGBOUNCER_LISTEN_ADDR}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_LISTEN_PORT}|${PGBOUNCER_LISTEN_PORT}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_AUTH_TYPE}|${PGBOUNCER_AUTH_TYPE}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_ADMIN_USERS}|${PGBOUNCER_ADMIN_USERS}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_STATS_USERS}|${PGBOUNCER_STATS_USERS}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_POOL_MODE}|${PGBOUNCER_POOL_MODE}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_MAX_CLIENT_CONN}|${PGBOUNCER_MAX_CLIENT_CONN}|g" "$temp_config_file"
    sed -i "s|\${PGBOUNCER_DEFAULT_POOL_SIZE}|${PGBOUNCER_DEFAULT_POOL_SIZE}|g" "$temp_config_file"

    if [ -n "${IGNORE_STARTUP_PARAMETERS:-}" ]; then
      cat << EOF
ignore_startup_parameters = ${IGNORE_STARTUP_PARAMETERS}
EOF
    fi

    # Calculate hash of new configuration
    local new_hash
    new_hash=$(sha256sum "$temp_config_file" | awk '{print $1}')

    # Check if configuration has changed
    local old_hash=""
    if [ -f "$config_hash_file" ]; then
        old_hash=$(cat "$config_hash_file")
    fi

    if [ "$new_hash" != "$old_hash" ]; then
        log_info "PgBouncer configuration has changed, reloading..."

        # Update the processed config file
        mv "$temp_config_file" "$processed_config_file"
        chown postgres:postgres "$processed_config_file"
        chmod 600 "$processed_config_file"

        # Update hash file
        echo "$new_hash" > "$config_hash_file"

        # Find PgBouncer PID and send SIGHUP to reload configuration
        local pgb_pid
        pgb_pid=$(pgrep -f "pgbouncer" | head -1)

        if [ -n "$pgb_pid" ]; then
            if kill -HUP "$pgb_pid" 2>/dev/null; then
                log_info "PgBouncer configuration reloaded successfully (PID: $pgb_pid)"
                return 0
            else
                log_error "Failed to reload PgBouncer configuration"
                return 1
            fi
        else
            log_error "Could not find PgBouncer PID for reload"
            return 1
        fi
    else
        # Clean up temp file
        rm -f "$temp_config_file"
        log_debug "PgBouncer configuration unchanged"
        return 0
    fi
}
