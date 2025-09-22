#!/bin/bash
# 02-database.sh - PostgreSQL database cluster initialization
# Initializes the PostgreSQL database cluster if it doesn't exist

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Main function
main() {
    log_script_start "02-database.sh"

    # Validate environment before proceeding
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    # Check if cluster already exists
    if check_cluster_exists; then
        log_info "PostgreSQL cluster already exists, skipping initialization"
        return 0
    fi

    # Initialize the cluster
    initialize_cluster

    # Verify cluster integrity
    verify_cluster_integrity

    log_script_end "02-database.sh"
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

# Execute main function
main "$@"