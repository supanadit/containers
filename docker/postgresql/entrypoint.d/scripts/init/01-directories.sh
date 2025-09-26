#!/bin/bash
# 01-directories.sh - Directory creation and permission setup
# Initializes required directories with proper ownership and permissions

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Main function
main() {
    log_script_start "01-directories.sh"

    # Validate environment before proceeding
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    # Apply container security measures
    apply_container_security

    # Create data directory
    create_data_directory

    # Create config directory
    create_config_directory

    # Create log directory
    create_log_directory

    # Create run directory
    create_run_directory

    # Create backup directory if backup is enabled
    if [ "${ENABLE_PGBACKREST:-false}" = "true" ]; then
        create_backup_directory
    fi

    # Set ownership on all directories
    set_directory_ownership

    log_script_end "01-directories.sh"
}

# Create PostgreSQL data directory
create_data_directory() {
    local data_dir="${PGDATA:-$DEFAULT_PGDATA}"

    log_info "Creating PostgreSQL data directory: $data_dir"

    # Create directory if it doesn't exist
    if [ ! -d "$data_dir" ]; then
        mkdir -p "$data_dir"
        log_info "Created data directory: $data_dir"
    else
        log_debug "Data directory already exists: $data_dir"
    fi

    # Set secure permissions
    set_secure_permissions "$data_dir"

    # For data directory, we want 700 permissions (owner only)
    chmod 700 "$data_dir"
    log_debug "Set restrictive permissions (700) on data directory"
}

# Create configuration directory
create_config_directory() {
    local config_dir="${PGCONFIG:-$DEFAULT_PGCONFIG}"

    log_info "Creating PostgreSQL config directory: $config_dir"

    # Create directory if it doesn't exist
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
        log_info "Created config directory: $config_dir"
    else
        log_debug "Config directory already exists: $config_dir"
    fi

    # Set secure permissions
    set_secure_permissions "$config_dir"
}

# Create log directory
create_log_directory() {
    local log_dir="${PGLOG:-$DEFAULT_PGLOG}"

    log_info "Creating PostgreSQL log directory: $log_dir"

    # Create directory if it doesn't exist
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        log_info "Created log directory: $log_dir"
    else
        log_debug "Log directory already exists: $log_dir"
    fi

    # Set secure permissions
    set_secure_permissions "$log_dir"
}

# Create run directory for PID files and sockets
create_run_directory() {
    local run_dir="${PGRUN:-$DEFAULT_PGRUN}"

    log_info "Creating PostgreSQL run directory: $run_dir"

    # Create directory if it doesn't exist
    if [ ! -d "$run_dir" ]; then
        mkdir -p "$run_dir"
        log_info "Created run directory: $run_dir"
    else
        log_debug "Run directory already exists: $run_dir"
    fi

    # Set secure permissions
    set_secure_permissions "$run_dir"
}

# Create backup directory for pgBackRest
create_backup_directory() {
    local backup_dir="${PGBACKUP:-$DEFAULT_PGBACKUP}"

    log_info "Creating PostgreSQL backup directory: $backup_dir"

    # Create directory if it doesn't exist
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        log_info "Created backup directory: $backup_dir"
    else
        log_debug "Backup directory already exists: $backup_dir"
    fi

    # Set secure permissions
    set_secure_permissions "$backup_dir"

    # Create subdirectory structure for pgBackRest
    local backup_spool="$backup_dir/spool"
    local backup_log="$backup_dir/log"

    mkdir -p "$backup_spool" "$backup_log"
    set_secure_permissions "$backup_spool"
    set_secure_permissions "$backup_log"

    log_debug "Created pgBackRest subdirectories: spool, log"
}

# Set ownership on all PostgreSQL directories
set_directory_ownership() {
    local postgres_user="$POSTGRES_USER"
    local postgres_group="$POSTGRES_GROUP"

    log_info "Setting ownership to $postgres_user:$postgres_group on PostgreSQL directories"

    # List of directories to set ownership on
    local dirs=("${PGDATA:-$DEFAULT_PGDATA}" "${PGCONFIG:-$DEFAULT_PGCONFIG}" "${PGLOG:-$DEFAULT_PGLOG}" "${PGRUN:-$DEFAULT_PGRUN}")

    # Add backup directory if it exists
    if [ "${ENABLE_PGBACKREST:-false}" = "true" ]; then
        dirs+=("${PGBACKUP:-$DEFAULT_PGBACKUP}")
    fi

    # Set ownership on each directory
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            chown -R "$postgres_user:$postgres_group" "$dir"
            log_debug "Set ownership on directory: $dir"
        fi
    done
}

# Execute main function
main "$@"