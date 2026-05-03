#!/bin/bash
# entrypoint.sh - Main container orchestrator for MariaDB
# Coordinates all modular scripts for MariaDB container initialization and runtime

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

SCRIPT_VERSION="1.0.0"

DEFAULT_MARIADB_DATA_DIR="${DEFAULT_MARIADB_DATA_DIR:-/var/lib/mysql}"
DEFAULT_MARIADB_CONFIG_DIR="${DEFAULT_MARIADB_CONFIG_DIR:-/etc/mysql/mariadb.conf.d}"
DEFAULT_MARIADB_LOG_DIR="${DEFAULT_MARIADB_LOG_DIR:-/var/log/mariadb}"
DEFAULT_MARIADB_RUN_DIR="${DEFAULT_MARIADB_RUN_DIR:-/run/mariadb}"
DEFAULT_MARIADB_BACKUP_DIR="${DEFAULT_MARIADB_BACKUP_DIR:-/var/lib/mariadb/backup}"

export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-$DEFAULT_MARIADB_DATA_DIR}"
export MARIADB_CONFIG_DIR="${MARIADB_CONFIG_DIR:-$DEFAULT_MARIADB_CONFIG_DIR}"
export MARIADB_LOG_DIR="${MARIADB_LOG_DIR:-$DEFAULT_MARIADB_LOG_DIR}"
export MARIADB_RUN_DIR="${MARIADB_RUN_DIR:-$DEFAULT_MARIADB_RUN_DIR}"
export MARIADB_BACKUP_DIR="${MARIADB_BACKUP_DIR:-$DEFAULT_MARIADB_BACKUP_DIR}"

export MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
export MARIADB_DATABASE="${MARIADB_DATABASE:-}"
export MARIADB_USER="${MARIADB_USER:-}"
export MARIADB_PASSWORD="${MARIADB_PASSWORD:-}"
export MARIADB_ALLOW_EMPTY_PASSWORD="${MARIADB_ALLOW_EMPTY_PASSWORD:-no}"

export MARIADB_MAX_CONNECTIONS="${MARIADB_MAX_CONNECTIONS:-200}"
export MARIADB_INNODB_BUFFER_POOL_SIZE="${MARIADB_INNODB_BUFFER_POOL_SIZE:-128M}"
export MARIADB_INNODB_LOG_FILE_SIZE="${MARIADB_INNODB_LOG_FILE_SIZE:-48M}"
export MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT="${MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT:-1}"
export MARIADB_TIMEZONE="${MARIADB_TIMEZONE:-UTC}"
export MARIADB_EXPIRE_LOGS_DAYS="${MARIADB_EXPIRE_LOGS_DAYS:-7}"

export MARIADB_REPLICATION_ENABLE="${MARIADB_REPLICATION_ENABLE:-false}"
export MARIADB_REPLICATION_USER="${MARIADB_REPLICATION_USER:-repl}"
export MARIADB_REPLICATION_PASSWORD="${MARIADB_REPLICATION_PASSWORD:-}"

export MARIADB_GALERA_ENABLE="${MARIADB_GALERA_ENABLE:-false}"
export MARIADB_GALERA_CLUSTER_NAME="${MARIADB_GALERA_CLUSTER_NAME:-mariadb_cluster}"
export MARIADB_GALERA_SEEDS="${MARIADB_GALERA_SEEDS:-}"
export MARIADB_GALERA_SST_METHOD="${MARIADB_GALERA_SST_METHOD:-xtrabackup}"
export MARIADB_GALERA_PROVIDER="${MARIADB_GALERA_PROVIDER:-}"
export MARIADB_NODE_ADDRESS="${MARIADB_NODE_ADDRESS:-localhost}"
export MARIADB_GALERA_THREADS="${MARIADB_GALERA_THREADS:-4}"

export MARIADB_BACKUP_ENABLE="${MARIADB_BACKUP_ENABLE:-false}"
export MARIADB_BACKUP_METHOD="${MARIADB_BACKUP_METHOD:-xtrabackup}"
export MARIADB_BACKUP_RETENTION_DAYS="${MARIADB_BACKUP_RETENTION_DAYS:-7}"
export MARIADB_BACKUP_SCHEDULE="${MARIADB_BACKUP_SCHEDULE:-0 2 * * *}"

export MARIADB_SSL_ENABLE="${MARIADB_SSL_ENABLE:-false}"
export MARIADB_SSL_CERT_DIR="${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}"

export MARIADB_EXTERNAL_ACCESS_ENABLE="${MARIADB_EXTERNAL_ACCESS_ENABLE:-false}"

main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"

    log_info "MariaDB Container Entrypoint v$SCRIPT_VERSION"
    log_environment

    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi

    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi

    setup_signal_handlers

    run_initialization

    start_runtime

    log_script_end "entrypoint.sh"
}

setup_signal_handlers() {
    log_debug "Setting up signal handlers"

    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP

    log_debug "Signal handlers configured"
}

handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"

    if [ -f "/opt/container/entrypoint.d/scripts/runtime/shutdown.sh" ]; then
        /opt/container/entrypoint.d/scripts/runtime/shutdown.sh || true
    fi

    log_info "Shutdown complete"
    exit 0
}

run_initialization() {
    log_info "Running initialization scripts"

    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/00-misc-scripts.sh"
        "/opt/container/entrypoint.d/scripts/init/01-directories.sh"
        "/opt/container/entrypoint.d/scripts/init/02-database.sh"
        "/opt/container/entrypoint.d/scripts/init/03-config.sh"
        "/opt/container/entrypoint.d/scripts/init/04-backup.sh"
        "/opt/container/entrypoint.d/scripts/init/05-sshd.sh"
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

start_runtime() {
    log_info "Starting runtime management"

    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"

    if [ -f "$startup_script" ] && [ -x "$startup_script" ]; then
        log_info "Starting MariaDB via startup script"
        exec "$startup_script"
    else
        log_error "Startup script not found or not executable: $startup_script"
        exit 1
    fi
}

main "$@"