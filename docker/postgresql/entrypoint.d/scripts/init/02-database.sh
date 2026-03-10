#!/bin/bash
# 02-database.sh - PostgreSQL database cluster initialization
# Initializes the PostgreSQL database cluster if it doesn't exist

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Set password modification timeout (default 5 seconds)
TIMEOUT_CHANGE_PASSWORD=${TIMEOUT_CHANGE_PASSWORD:-5}

# Restore coordination files
RESTORE_STATE_DIR="${PGRUN:-${DEFAULT_PGRUN:-/usr/local/pgsql/run}}"
RESTORE_SENTINEL="${RESTORE_STATE_DIR}/pgbackrest-restore.pending"
RESTORE_COMPLETE_MARK="${RESTORE_STATE_DIR}/pgbackrest-restore.complete"

# Sanitize password for SQL usage (escape single quotes)
sanitize_password() {
    local password="$1"
    echo "$password" | sed "s/'/''/g"
}

# Main function
main() {
    log_script_start "02-database.sh"

    # Validate environment before proceeding
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    # Clear any previous restore state marks to avoid confusion on fresh startups
    cleanup_stale_restore_markers

    local cluster_exists=false
    if check_cluster_exists; then
        cluster_exists=true
    fi

    if is_restore_requested; then
        if [ "${PGBACKREST_ENABLE:-false}" != "true" ]; then
            log_error "PGBACKREST_RESTORE=true requires PGBACKREST_ENABLE=true"
            return 1
        fi
        if ! prepare_restore_environment; then
            log_error "Failed to prepare PostgreSQL data directory for restore"
            return 1
        fi
        if ! mark_restore_pending; then
            log_error "Failed to mark restore state"
            return 1
        fi
        log_info "Restore requested; skipping cluster initialization until runtime restore completes"
        log_script_end "02-database.sh"
        return 0
    fi

    # Check if cluster already exists
    if [ "$cluster_exists" = true ]; then
        log_info "PostgreSQL cluster already exists, skipping initialization"
        return 0
    fi

    # Skip initialization in Patroni mode - let Patroni handle bootstrap
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        log_info "Patroni mode enabled, skipping database initialization - Patroni will handle bootstrap"
        return 0
    fi

    # Handle native HA replica setup
    if [[ "${HA_MODE:-}" == "native" && "${REPLICATION_ROLE:-}" == "replica" ]]; then
        clone_primary
        return 0
    fi

    # Initialize the cluster
    initialize_cluster

    # Set postgres user password if provided
    if [[ -n "${POSTGRES_PASSWORD:-}" ]]; then
        if ! set_postgres_password; then
            log_error "Failed to set postgres password"
            return 1
        fi
    fi

    # Create replication user for native HA primary
    if [[ "${HA_MODE:-}" == "native" && "${REPLICATION_ROLE:-}" == "primary" ]]; then
        create_replication_user
    fi

    # Verify cluster integrity
    verify_cluster_integrity

    log_script_end "02-database.sh"
}

# Determine whether a pgBackRest restore is requested
is_restore_requested() {
    local flag="${PGBACKREST_RESTORE:-false}"
    case "${flag,,}" in
        true|1|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# Remove stale restore markers so that a previous run does not interfere
cleanup_stale_restore_markers() {
    mkdir -p "$RESTORE_STATE_DIR"
    if [ -f "$RESTORE_SENTINEL" ]; then
        log_debug "Removing stale restore sentinel: $RESTORE_SENTINEL"
        rm -f "$RESTORE_SENTINEL"
    fi
}

# Prepare data directory for pgBackRest restore
prepare_restore_environment() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local postgres_user="${POSTGRES_USER:-postgres}"
    local postgres_group="${POSTGRES_GROUP:-postgres}"

    if [ -d "$data_dir" ] && [ -n "$(ls -A "$data_dir" 2>/dev/null)" ]; then
        local backup_path="${data_dir}.pre-restore.$(date +%s)"
        log_warn "Data directory $data_dir is not empty; moving existing contents to $backup_path"
        if ! mv "$data_dir" "$backup_path"; then
            log_warn "Standard move failed; attempting copy-and-clean fallback"
            mkdir -p "$backup_path"
            if cp -a "$data_dir/." "$backup_path/"; then
                chown -R "$postgres_user:$postgres_group" "$backup_path"
                find "$data_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
            else
                log_error "Failed to safeguard existing data directory contents"
                return 1
            fi
        fi
    fi

    # Recreate empty data directory owned by postgres
    mkdir -p "$data_dir"
    chown "$postgres_user:$postgres_group" "$data_dir"
    chmod 700 "$data_dir"

    return 0
}

# Create a sentinel file indicating that restore should run during startup
mark_restore_pending() {
    mkdir -p "$RESTORE_STATE_DIR"
    if printf 'requested_at=%s\n' "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" >"$RESTORE_SENTINEL"; then
        chmod 600 "$RESTORE_SENTINEL"
        return 0
    fi
    return 1
}

# Check if PostgreSQL cluster already exists
check_cluster_exists() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_debug "Checking if PostgreSQL cluster exists in: $data_dir"

    # Check for key files that indicate a cluster exists
    local key_files=("PG_VERSION" "postgresql.conf" "pg_hba.conf")

    for file in "${key_files[@]}"; do
        if [ -f "$data_dir/$file" ]; then
            log_debug "Found cluster file: $file"
            return 0
        fi
    done

    log_debug "No cluster files found, cluster does not exist"
    return 1
}

# Clone primary for native HA replica
clone_primary() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Cloning primary database for replica setup..."

    # Ensure data directory is empty
    if [ -n "$(ls -A "$data_dir")" ]; then
        log_error "Data directory is not empty. Cannot clone primary."
        return 1
    fi

    # Set PGPASSWORD for pg_basebackup
    export PGPASSWORD="${REPLICATION_PASSWORD}"

    local backup_cmd="pg_basebackup"
    local backup_args=(
        -h "${PRIMARY_HOST}"
        -p "${PRIMARY_PORT:-5432}"
        -U "${REPLICATION_USER:-replicator}"
        -D "$data_dir"
        -Fp  # Plain format
        -Xs  # Stream WAL content
        -R   # Create standby.signal and write connection to postgresql.auto.conf
    )

    log_debug "Running pg_basebackup with args: ${backup_args[*]}"

    if ! su -c "$backup_cmd ${backup_args[*]}" postgres; then
        log_error "Failed to clone primary database."
        # Clean up failed backup attempt
        rm -rf "$data_dir"/*
        return 1
    fi

    unset PGPASSWORD
    log_info "Successfully cloned primary database."
}

# Initialize PostgreSQL cluster
initialize_cluster() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Initializing PostgreSQL cluster in: $data_dir"

    # Ensure data directory exists and has correct permissions
    if [ ! -d "$data_dir" ]; then
        log_error "Data directory does not exist: $data_dir"
        return 1
    fi

    # Check if directory is writable
    if [ ! -w "$data_dir" ]; then
        log_error "Data directory is not writable: $data_dir"
        return 1
    fi

    # Run initdb as postgres user
    local initdb_cmd="initdb"
    local initdb_args=()

    # Add authentication method (trust for local connections during init)
    initdb_args+=("--auth=trust")
    initdb_args+=("--username=postgres")
    initdb_args+=("--encoding=UTF-8")
    initdb_args+=("--locale=C")

    # Add data directory
    initdb_args+=("--pgdata=$data_dir")

    log_debug "Running initdb with args: ${initdb_args[*]}"

    # Execute initdb as postgres user
    if ! su -c "$initdb_cmd ${initdb_args[*]}" postgres; then
        log_error "Failed to initialize PostgreSQL cluster"
        return 1
    fi

    log_info "Successfully initialized PostgreSQL cluster"

    # Set secure permissions on newly created files (PostgreSQL data dir needs 700)
    chmod 700 "$data_dir"
    log_debug "Set PostgreSQL data directory permissions to 700"

    # Ensure PG_VERSION file exists and is readable
    if [ -f "$data_dir/PG_VERSION" ]; then
        chmod 644 "$data_dir/PG_VERSION"
    fi
}

# Verify cluster integrity after initialization
verify_cluster_integrity() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_debug "Verifying cluster integrity"

    # Check that essential files were created
    local required_files=("PG_VERSION" "postgresql.conf" "pg_hba.conf" "pg_ident.conf")

    for file in "${required_files[@]}"; do
        if [ ! -f "$data_dir/$file" ]; then
            log_error "Required cluster file missing: $file"
            return 1
        fi
        log_debug "Verified cluster file exists: $file"
    done

    # Check that essential directories were created
    local required_dirs=("base" "global" "pg_xact" "pg_wal")

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$data_dir/$dir" ]; then
            log_error "Required cluster directory missing: $dir"
            return 1
        fi
        log_debug "Verified cluster directory exists: $dir"
    done

    # Try to start PostgreSQL briefly to verify it works
    log_debug "Testing cluster startup capability"

    # Use pg_ctl to do a quick startup test
    local pg_ctl_cmd="pg_ctl"
    local pg_ctl_args=("-D" "$data_dir" "-o" "--config-file=/dev/null" "-s")

    # Create a minimal config for testing
    local test_config
    test_config=$(create_secure_temp_file "pg_test_config")

    cat > "$test_config" << EOF
listen_addresses = ''
port = 5433  # Use a different port for testing
unix_socket_directories = '$data_dir'
EOF

    # Make config file readable by postgres user
    chmod 644 "$test_config"

    # Try to start PostgreSQL
    if su -c "$pg_ctl_cmd -D $data_dir -o \"--config-file=$test_config\" -s start" postgres; then
        # Wait a moment for startup
        sleep 2

        # Check if it's running
        if su -c "$pg_ctl_cmd -D $data_dir status" postgres >/dev/null 2>&1; then
            log_debug "Cluster startup test successful"

            # Stop the test instance
            su -c "$pg_ctl_cmd -D $data_dir -s stop" postgres
            log_debug "Stopped test cluster instance"
        else
            log_error "Cluster failed to start properly"
            secure_cleanup "$test_config"
            return 1
        fi
    else
        log_error "Failed to start cluster for testing"
        secure_cleanup "$test_config"
        return 1
    fi

    # Clean up test config
    secure_cleanup "$test_config"

    log_info "Cluster integrity verification completed successfully"
}

# Set postgres user password
set_postgres_password() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local password="$POSTGRES_PASSWORD"
    local sanitized_password
    sanitized_password=$(sanitize_password "$password")

    log_info "Setting postgres user password"

    # Create temporary config for password setting
    local temp_config
    temp_config=$(create_secure_temp_file "pg_password_config")

    cat > "$temp_config" << EOF
listen_addresses = 'localhost'
port = 5433
unix_socket_directories = '$data_dir'
password_encryption = scram-sha-256
EOF

    chmod 644 "$temp_config"

    # Trap for graceful shutdown
    trap 'log_info "Shutdown signal received, aborting password setting"; su -c "pg_ctl -D $data_dir -s stop" postgres 2>/dev/null || true; secure_cleanup "$temp_config" 2>/dev/null || true; exit 1' TERM INT

    # Start postgres temporarily
    if ! su -c "pg_ctl -D $data_dir -o \"--config-file=$temp_config\" -s start" postgres; then
        log_error "Failed to start postgres for password setting"
        secure_cleanup "$temp_config"
        return 1
    fi

    # Wait for startup
    sleep 2

    # Set password with timeout
    local sql="ALTER USER postgres PASSWORD '$sanitized_password';"
    if ! timeout "$TIMEOUT_CHANGE_PASSWORD" su -c "psql -h localhost -p 5433 -U postgres -d postgres -c \"$sql\"" postgres; then
        log_error "Failed to set password within timeout"
        su -c "pg_ctl -D $data_dir -s stop" postgres
        secure_cleanup "$temp_config"
        return 1
    fi

    # Stop postgres
    su -c "pg_ctl -D $data_dir -s stop" postgres

    secure_cleanup "$temp_config"

    log_info "Successfully set postgres user password"
}

# Create replication user
create_replication_user() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local replication_user="${REPLICATION_USER:-replicator}"
    local replication_password="${REPLICATION_PASSWORD:-replicator_password}"

    log_info "Creating replication user: $replication_user"

    # Create temporary config for user creation
    local temp_config
    temp_config=$(create_secure_temp_file "pg_replication_config")

    cat > "$temp_config" << EOF
listen_addresses = 'localhost'
port = 5433
unix_socket_directories = '$data_dir'
password_encryption = scram-sha-256
EOF

    chmod 644 "$temp_config"

    # Trap for graceful shutdown
    trap 'log_info "Shutdown signal received, aborting replication user creation"; su -c "pg_ctl -D $data_dir -s stop" postgres 2>/dev/null || true; secure_cleanup "$temp_config" 2>/dev/null || true; exit 1' TERM INT

    # Start postgres temporarily
    if ! su -c "pg_ctl -D $data_dir -o \"--config-file=$temp_config\" -s start" postgres; then
        log_error "Failed to start postgres for replication user creation"
        secure_cleanup "$temp_config"
        return 1
    fi

    # Wait for startup
    sleep 2

    # Create replication user with timeout
    local sql="CREATE USER $replication_user REPLICATION LOGIN PASSWORD '$replication_password';"
    if ! timeout "$TIMEOUT_CHANGE_PASSWORD" su -c "psql -h localhost -p 5433 -U postgres -d postgres -c \"$sql\"" postgres; then
        log_error "Failed to create replication user within timeout"
        su -c "pg_ctl -D $data_dir -s stop" postgres
        secure_cleanup "$temp_config"
        return 1
    fi

    # Stop postgres
    su -c "pg_ctl -D $data_dir -s stop" postgres

    secure_cleanup "$temp_config"

    log_info "Successfully created replication user: $replication_user"
}

# Export functions for use by other scripts
export -f clone_primary

# Execute main function
main "$@"