#!/bin/bash
# validation.sh - Configuration and environment validation utilities
# Provides validation functions for all container scripts

# Set strict error handling
set -euo pipefail

# Source logging utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

# Default values
DEFAULT_PGDATA="/usr/local/pgsql/data"
DEFAULT_PGCONFIG="/usr/local/pgsql/config"
DEFAULT_TIMEOUT=30

# Validate environment variables
validate_environment() {
    local exit_code=0

    log_debug "Validating environment variables"

    # Validate PGDATA
    if [ -z "${PGDATA:-}" ]; then
        PGDATA="$DEFAULT_PGDATA"
        log_info "PGDATA not set, using default: $PGDATA"
    fi

    if [ ! -d "$PGDATA" ] && [ ! -w "$(dirname "$PGDATA")" ]; then
        log_error "PGDATA directory is not writable: $PGDATA"
        return 1
    fi

    # Validate PGCONFIG
    if [ -z "${PGCONFIG:-}" ]; then
        PGCONFIG="$DEFAULT_PGCONFIG"
        log_info "PGCONFIG not set, using default: $PGCONFIG"
    fi

    # Validate LOG_LEVEL
    case "${LOG_LEVEL:-INFO}" in
        DEBUG|INFO|WARN|ERROR) ;;
        *)
            log_error "Invalid LOG_LEVEL: $LOG_LEVEL (must be DEBUG, INFO, WARN, or ERROR)"
            exit_code=1
            ;;
    esac

    # Validate TIMEOUT
    if [ -z "${TIMEOUT:-}" ]; then
        TIMEOUT="$DEFAULT_TIMEOUT"
    elif ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -le 0 ]; then
        log_error "Invalid TIMEOUT: $TIMEOUT (must be a positive integer)"
        exit_code=1
    fi

    # Validate mode flags
    case "${PATRONI_ENABLE:-false}" in
        true|false) ;;
        *)
            log_error "Invalid PATRONI_ENABLE: $PATRONI_ENABLE (must be true or false)"
            exit_code=1
            ;;
    esac

    case "${SLEEP_MODE:-false}" in
        true|false) ;;
        *)
            log_error "Invalid SLEEP_MODE: $SLEEP_MODE (must be true or false)"
            exit_code=1
            ;;
    esac

    case "${PGBACKREST_ENABLE:-false}" in
        true|false) ;;
        *)
            log_error "Invalid PGBACKREST_ENABLE: $PGBACKREST_ENABLE (must be true or false)"
            exit_code=1
            ;;
    esac

    # If pgBackRest enabled, validate repository type specifics
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ]; then
        local repo_type="${PGBACKREST_REPO_TYPE:-posix}"
        case "$repo_type" in
            posix|filesystem|s3|gcs|sftp) ;;
            *)
                log_error "Invalid PGBACKREST_REPO_TYPE: $repo_type (must be posix|filesystem|s3|gcs|sftp)"
                exit_code=1
                ;;
        esac

        if [ "$repo_type" = "s3" ]; then
            # Basic required vars for S3
            if [ -z "${PGBACKREST_REPO_S3_BUCKET:-}" ]; then
                log_error "PGBACKREST_REPO_S3_BUCKET is required when PGBACKREST_REPO_TYPE=s3"
                exit_code=1
            fi
            if [ -z "${PGBACKREST_REPO_S3_ENDPOINT:-}" ]; then
                log_error "PGBACKREST_REPO_S3_ENDPOINT is required when PGBACKREST_REPO_TYPE=s3 (can point to MinIO or S3 compatible endpoint)"
                exit_code=1
            fi
            # Optional: warn if credentials missing (may rely on IAM/anonymous)
            if [ -z "${PGBACKREST_REPO_S3_KEY:-}" ] || [ -z "${PGBACKREST_REPO_S3_KEY_SECRET:-}" ]; then
                log_warn "S3 key or secret not provided; ensure alternative auth (IAM/anonymous) is configured if required"
            fi
            if [ -n "${PGBACKREST_REPO_S3_PORT:-}" ] && ! [[ "${PGBACKREST_REPO_S3_PORT}" =~ ^[0-9]+$ ]]; then
                log_error "Invalid PGBACKREST_REPO_S3_PORT: ${PGBACKREST_REPO_S3_PORT} (must be numeric)"
                exit_code=1
            fi
            if [ -n "${PGBACKREST_REPO_S3_VERIFY_TLS:-}" ]; then
                case "${PGBACKREST_REPO_S3_VERIFY_TLS}" in
                    true|TRUE|false|FALSE|1|0|y|Y|n|N) ;; 
                    *)
                        log_error "Invalid PGBACKREST_REPO_S3_VERIFY_TLS: ${PGBACKREST_REPO_S3_VERIFY_TLS} (must be boolean-like)"
                        exit_code=1
                        ;;
                esac
            fi
        elif [ "$repo_type" = "gcs" ]; then
            # GCS requires at least a bucket
            if [ -z "${PGBACKREST_REPO_GCS_BUCKET:-}" ]; then
                log_error "PGBACKREST_REPO_GCS_BUCKET is required when PGBACKREST_REPO_TYPE=gcs"
                exit_code=1
            fi
            # Key type sanity (optional)
            if [ -n "${PGBACKREST_REPO_GCS_KEY_TYPE:-}" ]; then
                case "${PGBACKREST_REPO_GCS_KEY_TYPE}" in
                    auto|service|token) ;;
                    *)
                        log_error "Invalid PGBACKREST_REPO_GCS_KEY_TYPE: ${PGBACKREST_REPO_GCS_KEY_TYPE} (must be auto|service|token)"
                        exit_code=1
                        ;;
                esac
            fi
        elif [ "$repo_type" = "sftp" ]; then
            if [ -z "${PGBACKREST_REPO_SFTP_HOST:-}" ]; then
                log_error "PGBACKREST_REPO_SFTP_HOST is required when PGBACKREST_REPO_TYPE=sftp"
                exit_code=1
            fi
            if [ -n "${PGBACKREST_REPO_SFTP_HOST_PORT:-}" ] && ! [[ "${PGBACKREST_REPO_SFTP_HOST_PORT}" =~ ^[0-9]+$ ]]; then
                log_error "Invalid PGBACKREST_REPO_SFTP_HOST_PORT: ${PGBACKREST_REPO_SFTP_HOST_PORT} (must be numeric)"
                exit_code=1
            fi
            if [ -n "${PGBACKREST_REPO_SFTP_HOST_KEY_CHECK_TYPE:-}" ]; then
                case "${PGBACKREST_REPO_SFTP_HOST_KEY_CHECK_TYPE}" in
                    strict|accept-new|fingerprint|none) ;;
                    *)
                        log_error "Invalid PGBACKREST_REPO_SFTP_HOST_KEY_CHECK_TYPE: ${PGBACKREST_REPO_SFTP_HOST_KEY_CHECK_TYPE}"
                        exit_code=1
                        ;;
                esac
            fi
        fi
    fi

    # Validate PostgreSQL-specific variables
    if [ -n "${POSTGRESQL_SHARED_BUFFERS:-}" ]; then
        if ! validate_memory_value "$POSTGRESQL_SHARED_BUFFERS"; then
            log_error "Invalid POSTGRESQL_SHARED_BUFFERS: $POSTGRESQL_SHARED_BUFFERS"
            exit_code=1
        fi
    fi

    if [ -n "${POSTGRESQL_MAX_CONNECTIONS:-}" ]; then
        if ! [[ "$POSTGRESQL_MAX_CONNECTIONS" =~ ^[0-9]+$ ]] || [ "$POSTGRESQL_MAX_CONNECTIONS" -le 0 ]; then
            log_error "Invalid POSTGRESQL_MAX_CONNECTIONS: $POSTGRESQL_MAX_CONNECTIONS"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

# Validate configuration files
validate_config_files() {
    local exit_code=0

    log_debug "Validating configuration files"

    # Check if config directory exists
    if [ -n "${PGCONFIG:-}" ] && [ ! -d "$PGCONFIG" ]; then
        log_warn "Configuration directory does not exist: $PGCONFIG"
        return 0  # Not an error, just a warning
    fi

    # Validate postgresql.conf if it exists
    local postgres_conf="${PGCONFIG:-}/postgresql.conf"
    if [ -f "$postgres_conf" ]; then
        if ! validate_postgresql_conf "$postgres_conf"; then
            log_error "Invalid postgresql.conf: $postgres_conf"
            exit_code=1
        fi
    fi

    # Validate pg_hba.conf if it exists
    local pg_hba_conf="${PGCONFIG:-}/pg_hba.conf"
    if [ -f "$pg_hba_conf" ]; then
        if ! validate_pg_hba_conf "$pg_hba_conf"; then
            log_error "Invalid pg_hba.conf: $pg_hba_conf"
            exit_code=1
        fi
    fi

    # Validate Patroni config if it exists
    local patroni_conf="/etc/patroni.yml"
    if [ -f "$patroni_conf" ]; then
        if ! validate_patroni_config "$patroni_conf"; then
            log_error "Invalid patroni.yml: $patroni_conf"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

# Validate HA configuration
validate_ha_configuration() {
    local exit_code=0

    log_debug "Validating HA configuration"

    if [[ "${HA_MODE:-}" == "native" ]]; then
        if [[ "${PATRONI_ENABLE:-false}" == "true" ]]; then
            log_error "HA_MODE=native cannot be used with PATRONI_ENABLE=true"
            exit_code=1
        fi

        if [[ "${CITUS_ENABLE:-false}" == "true" ]]; then
            log_error "HA_MODE=native cannot be used with CITUS_ENABLE=true"
            exit_code=1
        fi

        if [[ "${REPLICATION_ROLE:-}" != "primary" && "${REPLICATION_ROLE:-}" != "replica" ]]; then
            log_error "Invalid REPLICATION_ROLE: ${REPLICATION_ROLE:-} (must be primary or replica)"
            exit_code=1
        fi

        if [[ "${REPLICATION_ROLE:-}" == "replica" && -z "${PRIMARY_HOST:-}" ]]; then
            log_error "PRIMARY_HOST must be set for replica role"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

# Validate file and directory permissions
validate_permissions() {
    local exit_code=0

    log_debug "Validating file and directory permissions"

    # Check PGDATA permissions
    if [ -d "${PGDATA:-}" ]; then
        local pgdata_perms
        pgdata_perms=$(stat -c "%a" "$PGDATA" 2>/dev/null || echo "unknown")
        if [ "$pgdata_perms" != "700" ] && [ "$pgdata_perms" != "755" ]; then
            log_warn "PGDATA permissions are not ideal: $pgdata_perms (recommended: 700 or 755)"
        fi
    fi

    # Check config file permissions
    local config_files=("${PGDATA:-}/postgresql.conf" "${PGDATA:-}/pg_hba.conf")
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            local file_perms
            file_perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "unknown")
            if [ "$file_perms" != "644" ] && [ "$file_perms" != "600" ]; then
                log_warn "Config file permissions are not ideal: $config_file ($file_perms)"
                if [ "${STRICT_PERMISSIONS:-false}" = "true" ]; then
                    log_error "Strict permissions required but not met for: $config_file"
                    exit_code=1
                fi
            fi
        fi
    done

    return "$exit_code"
}

# Validate required dependencies
validate_dependencies() {
    local exit_code=0

    log_debug "Validating required dependencies"

    # Check for required commands
    local required_commands=("pg_ctl" "initdb" "psql")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit_code=1
        fi
    done

    # Check for Patroni if enabled
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        if ! command -v "patroni" >/dev/null 2>&1; then
            log_error "Patroni is enabled but patroni command not found"
            exit_code=1
        fi
    fi

    # Check for pgBackRest if backup enabled
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ]; then
        if ! command -v "pgbackrest" >/dev/null 2>&1; then
            log_error "Backup is enabled but pgbackrest command not found"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

# Validate PostgreSQL configuration file
validate_postgresql_conf() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_error "PostgreSQL config file does not exist: $config_file"
        return 1
    fi

    if [ ! -r "$config_file" ]; then
        log_error "PostgreSQL config file is not readable: $config_file"
        return 1
    fi

    # Basic syntax check (this is a simple check, PostgreSQL would do more thorough validation)
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Check for basic parameter = value format
        if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
            local param="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            log_debug "Validated parameter: $param = $value"
        fi
    done < "$config_file"

    return 0
}

# Validate pg_hba.conf file
validate_pg_hba_conf() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_error "pg_hba config file does not exist: $config_file"
        return 1
    fi

    if [ ! -r "$config_file" ]; then
        log_error "pg_hba config file is not readable: $config_file"
        return 1
    fi

    # Basic format validation
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Basic format check (type, database, user, address, method)
        local field_count
        field_count=$(echo "$line" | awk '{print NF}')
        if [ "$field_count" -lt 4 ]; then
            log_warn "pg_hba.conf line $line_num has insufficient fields: $line"
        fi
    done < "$config_file"

    return 0
}

# Validate Patroni configuration file
validate_patroni_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_error "Patroni config file does not exist: $config_file"
        return 1
    fi

    if ! command -v "python3" >/dev/null 2>&1; then
        log_warn "Python not available, skipping YAML validation"
        return 0
    fi

    # Try to parse as YAML
    if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
        log_debug "Patroni config is valid YAML"
        return 0
    else
        log_error "Patroni config is not valid YAML: $config_file"
        return 1
    fi
}

# Validate memory value (e.g., "256MB", "1GB")
validate_memory_value() {
    local value="$1"

    # Check for valid memory units
    if [[ "$value" =~ ^[0-9]+(kB|MB|GB|TB)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use by other scripts
export -f validate_environment
export -f validate_config_files
export -f validate_ha_configuration
export -f validate_permissions
export -f validate_dependencies
export -f validate_postgresql_conf
export -f validate_pg_hba_conf
export -f validate_patroni_config
export -f validate_memory_value