#!/bin/bash
# 03-config.sh - PostgreSQL configuration file management
# Manages postgresql.conf, pg_hba.conf, and Patroni configuration

# Set strict error handling
set -euo pipefail

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

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

# Collect custom pg_hba.conf entries from PG_HBA_ADD_* environment variables
collect_custom_pg_hba_entries() {
    local -n entries_ref=$1
    entries_ref=()

    declare -A entries_map=()

    while IFS='=' read -r env_name env_value; do
        if [[ $env_name =~ ^PG_HBA_ADD_([0-9]+)$ ]]; then
            entries_map["${BASH_REMATCH[1]}"]="$env_value"
        fi
    done < <(env)

    if [ ${#entries_map[@]} -eq 0 ]; then
        return 0
    fi

    local sorted_keys
    IFS=$'\n' sorted_keys=($(printf '%s\n' "${!entries_map[@]}" | sort -n))

    for key in "${sorted_keys[@]}"; do
        local value="${entries_map[$key]}"
        value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [ -n "$value" ]; then
            entries_ref+=("${key}|${value}")
        fi
    done
}

# Remove a specific line from pg_hba.conf (exact match)
remove_pg_hba_line() {
    local hba_file="$1"
    local line="$2"

    if [ ! -f "$hba_file" ]; then
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp)"

    awk -v target="$line" '
        BEGIN { removed = 0 }
        {
            if (!removed && $0 == target) {
                removed = 1
                next
            }
            print $0
        }
    ' "$hba_file" > "$tmp_file"

    mv "$tmp_file" "$hba_file"
    set_secure_permissions "$hba_file"
}

# Main function
main() {
    log_script_start "03-config.sh"

    # Validate environment before proceeding
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi

    local restore_pending=false
    if is_restore_pending; then
        restore_pending=true
        log_info "pgBackRest restore pending; deferring direct modifications to postgresql.conf and pg_hba.conf"
    fi

    if ! $restore_pending; then
        # Backup original configurations
        backup_original_configs

        # Copy user-provided configurations
        copy_user_configs

        # Generate secure default configurations
        generate_secure_defaults

        # Apply environment variable overrides
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            apply_environment_overrides
        else
            log_info "Patroni mode enabled, skipping environment overrides on config files"
        fi

        # Apply external access configuration
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            apply_external_access_config
        else
            log_info "Patroni mode enabled, external access will be configured in patroni.yml"
        fi

        # Apply custom pg_hba.conf entries from environment variables
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            apply_custom_pg_hba_entries
        else
            log_info "Patroni mode enabled, custom pg_hba entries will be applied to patroni.yml"
        fi

        # Apply Citus configuration if enabled
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            apply_citus_configuration
        else
            log_info "Patroni mode enabled, Citus configuration will be in patroni.yml bootstrap"
        fi

        # Apply native HA configuration
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            apply_native_ha_config
        else
            log_info "Patroni mode enabled, HA configuration is handled by Patroni"
        fi

        # Validate final configurations
        if [ "${PATRONI_ENABLE:-false}" != "true" ]; then
            validate_final_configs
        else
            log_info "Patroni mode enabled, skipping config file validation - Patroni manages configs"
        fi
    else
        log_debug "Skipping PostgreSQL config file manipulation until restore completes"
    fi

    # Generate Patroni configuration if needed
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        generate_patroni_config
    fi

    log_script_end "03-config.sh"
}

# Determine whether a restore has been requested and is pending
is_restore_pending() {
    local run_dir="${PGRUN:-${DEFAULT_PGRUN:-/usr/local/pgsql/run}}"
    local sentinel="$run_dir/pgbackrest-restore.pending"
    [ -f "$sentinel" ]
}

# Backup original configuration files
backup_original_configs() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Backing up original configuration files"

    local config_files=("postgresql.conf" "pg_hba.conf")

    for file in "${config_files[@]}"; do
        local source_file="$data_dir/$file"
        local backup_file="$data_dir/$file.original"

        if [ -f "$source_file" ] && [ ! -f "$backup_file" ]; then
            cp "$source_file" "$backup_file"
            # Set permissions so postgres can read the backup files
            chown postgres:postgres "$backup_file"
            chmod 644 "$backup_file"
            log_debug "Backed up $file to $file.original"
        elif [ -f "$backup_file" ]; then
            log_debug "Backup already exists for $file"
        else
            log_warn "Source file does not exist: $source_file"
        fi
    done
}

# Copy user-provided configuration files
copy_user_configs() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local config_dir="${PGCONFIG:-/usr/local/pgsql/config}"

    log_info "Copying user-provided configuration files"

    # Only proceed if config directory exists
    if [ ! -d "$config_dir" ]; then
        log_debug "Config directory does not exist, skipping user config copy"
        return 0
    fi

    local config_files=("postgresql.conf" "pg_hba.conf")

    for file in "${config_files[@]}"; do
        local source_file="$config_dir/$file"
        local dest_file="$data_dir/$file"

        if [ -f "$source_file" ]; then
            cp "$source_file" "$dest_file"
            set_secure_permissions "$dest_file"
            log_info "Copied user config: $file"
        else
            log_debug "User config not provided: $file"
        fi
    done
}

# Generate secure default configurations
generate_secure_defaults() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Generating secure default configurations"

    # Skip generating configs in data dir for Patroni - let Patroni manage them
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        log_info "Patroni mode enabled, skipping config generation in data directory"
        return 0
    fi

    # Generate postgresql.conf if it doesn't exist
    if [ ! -f "$data_dir/postgresql.conf" ]; then
        generate_postgresql_conf "$data_dir/postgresql.conf"
    fi

    # Generate pg_hba.conf if it doesn't exist
    if [ ! -f "$data_dir/pg_hba.conf" ]; then
        generate_pg_hba_conf "$data_dir/pg_hba.conf"
    fi
}

# Generate secure postgresql.conf
generate_postgresql_conf() {
    local config_file="$1"

    log_debug "Generating postgresql.conf: $config_file"

    cat > "$config_file" << EOF
# PostgreSQL configuration generated by container
# Basic settings
listen_addresses = '*'
port = 5432
max_connections = 100

# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 4MB

# WAL settings
wal_level = replica
archive_mode = off
archive_command = ''

# Logging settings
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_statement = 'ddl'
log_duration = on
log_min_duration_statement = 1000

# Security settings
ssl = off
password_encryption = scram-sha-256

# Performance settings
random_page_cost = 1.1
effective_io_concurrency = 200

# Autovacuum settings
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 20s

# Other settings
timezone = '${POSTGRESQL_TIMEZONE:-UTC}'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
EOF

    set_secure_permissions "$config_file"
    log_debug "Generated secure postgresql.conf"
}

# Generate secure pg_hba.conf
generate_pg_hba_conf() {
    local config_file="$1"

    log_debug "Generating pg_hba.conf: $config_file"

    cat > "$config_file" << 'EOF'
# PostgreSQL Host Based Authentication configuration
# Generated by container

# Local connections (trust for postgres user)
local   all             postgres                                trust
local   all             all                                     md5

# Docker container connections
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5

# Replication connections (if needed)
# host    replication     replicator      0.0.0.0/0               md5
EOF

    set_secure_permissions "$config_file"
    log_debug "Generated secure pg_hba.conf"
}

# Apply environment variable overrides
apply_environment_overrides() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Applying environment variable overrides"

    # PostgreSQL settings overrides
    apply_postgres_setting "shared_buffers" "${POSTGRESQL_SHARED_BUFFERS:-}"
    apply_postgres_setting "max_connections" "${POSTGRESQL_MAX_CONNECTIONS:-}"
    apply_postgres_setting "work_mem" "${POSTGRESQL_WORK_MEM:-}"
    apply_postgres_setting "maintenance_work_mem" "${POSTGRESQL_MAINTENANCE_WORK_MEM:-}"
    apply_postgres_setting "listen_addresses" "${POSTGRESQL_LISTEN_ADDRESSES:-}"
    apply_postgres_setting "unix_socket_directories" "${POSTGRESQL_UNIX_SOCKET_DIRECTORIES:-${PGRUN:-/usr/local/pgsql/run}}"
    apply_postgres_setting "log_statement" "${POSTGRESQL_LOG_STATEMENT:-}"
    apply_postgres_setting "log_duration" "${POSTGRESQL_LOG_DURATION:-}"
    apply_postgres_setting "timezone" "${POSTGRESQL_TIMEZONE:-}"

    # Archive settings
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ]; then
        local clean_env_cmd
        clean_env_cmd="$(generate_clean_env_command)"
        apply_postgres_setting "archive_mode" "on"
        apply_postgres_setting "archive_command" "$clean_env_cmd pgbackrest --config=/etc/pgbackrest.conf --stanza=${PGBACKREST_STANZA:-default} archive-push %p"
    else
        apply_postgres_setting "archive_mode" "off"
    fi
}

# Apply a single PostgreSQL setting
apply_postgres_setting() {
    local setting="$1"
    local value="$2"

    if [ -z "$value" ]; then
        return 0
    fi

    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local config_file="$data_dir/postgresql.conf"

    log_debug "Applying PostgreSQL setting: $setting = $value"

    # Remove any existing occurrences (commented or uncommented)
    sed -i -E "/^[[:space:]]*#?[[:space:]]*${setting}[[:space:]]*=.*/d" "$config_file"

    # Determine formatting based on value type
    local formatted_value
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        formatted_value="$value"
    elif [[ "$value" =~ ^(on|off|true|false|replica|minimal|archive|hot_standby)$ ]]; then
        formatted_value="$value"
    elif [[ "$value" =~ ^[0-9]+(kB|MB|GB|TB|ms|s|min|h|d)$ ]]; then
        formatted_value="$value"
    else
        printf -v formatted_value "'%s'" "$value"
    fi

    echo "${setting} = ${formatted_value}" >> "$config_file"
}

# Determine if Citus is enabled via environment
is_citus_enabled() {
    local flag="${CITUS_ENABLE:-false}"
    [[ "${flag,,}" == "true" ]]
}

# Ensure shared_preload_libraries contains a specific library without duplicates
ensure_shared_preload_library() {
    local library="$1"
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local config_file="$data_dir/postgresql.conf"

    local current_line
    current_line=$(grep -E "^[[:space:]]*shared_preload_libraries" "$config_file" || true)

    local current_value=""
    if [ -n "$current_line" ]; then
        current_value=$(echo "$current_line" | cut -d'=' -f2- | sed -e "s/#.*//" -e "s/'//g" -e 's/"//g' -e 's/[[:space:]]//g')
    fi

    local updated_list="$current_value"
    if [ -z "$current_value" ]; then
        updated_list="$library"
    else
        local found="false"
        IFS=',' read -ra existing_libs <<< "$current_value"
        for existing in "${existing_libs[@]}"; do
            if [[ "$existing" == "$library" ]]; then
                found="true"
                break
            fi
        done
        if [ "$found" = "false" ]; then
            updated_list="${current_value},${library}"
        fi
    fi

    apply_postgres_setting "shared_preload_libraries" "$updated_list"
}

# Apply Citus-related configuration to postgresql.conf when enabled
apply_citus_configuration() {
    if ! is_citus_enabled; then
        log_debug "Citus not enabled; skipping configuration"
        return 0
    fi

    log_info "Applying Citus configuration"

    ensure_shared_preload_library "citus"

    local max_workers="${CITUS_MAX_WORKER_PROCESSES:-8}"
    apply_postgres_setting "citus.max_worker_processes" "$max_workers"

    local executor_mode="${CITUS_DISTRIBUTED_EXECUTOR:-adaptive}"
    apply_postgres_setting "citus.distributed_executor" "$executor_mode"

    if [ -n "${CITUS_NODE_NAME:-}" ]; then
        apply_postgres_setting "citus.node_name" "${CITUS_NODE_NAME}"
    fi

    local citus_role="${CITUS_ROLE:-coordinator}"
    if [[ "${citus_role}" == "coordinator" ]]; then
        apply_postgres_setting "citus.enable_control_commands" "true"
    else
        apply_postgres_setting "citus.enable_control_commands" "false"
    fi

    return 0
}

# Apply native HA configuration
apply_native_ha_config() {
    if [[ "${HA_MODE:-}" == "native" ]]; then
        log_info "Applying native HA configuration"
        apply_postgres_setting "listen_addresses" "*"
        apply_postgres_setting "wal_level" "replica"
        apply_postgres_setting "max_wal_senders" "10"
        apply_postgres_setting "wal_keep_size" "256MB"
        apply_postgres_setting "hot_standby" "on"

        if [[ "${REPLICATION_ROLE:-}" == "primary" ]]; then
            local hba_file="${PGDATA:-/usr/local/pgsql/data}/pg_hba.conf"
            local replication_user="${REPLICATION_USER:-replicator}"
            if ! grep -q "host replication $replication_user" "$hba_file"; then
                echo "host replication $replication_user 0.0.0.0/0 scram-sha-256" >> "$hba_file"
            fi
        fi
    fi
}

# Validate final configurations
validate_final_configs() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"

    log_info "Validating final configurations"

    # Validate postgresql.conf
    if ! validate_postgresql_conf "$data_dir/postgresql.conf"; then
        log_error "Final postgresql.conf validation failed"
        return 1
    fi

    # Validate pg_hba.conf
    if ! validate_pg_hba_conf "$data_dir/pg_hba.conf"; then
        log_error "Final pg_hba.conf validation failed"
        return 1
    fi

    log_info "Configuration validation successful"
}

# Generate Patroni configuration
generate_patroni_config() {
    log_info "Generating Patroni configuration"

    local patroni_config="/etc/patroni.yml"
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local rest_listen_host="${PATRONI_REST_HOST:-0.0.0.0}"
    local rest_port="${PATRONI_REST_PORT:-8008}"
    local rest_connect_host="${PATRONI_REST_CONNECT_HOST:-${POSTGRESQL_CONNECT_HOST:-}}"

    if [ -z "$rest_connect_host" ] || [ "$rest_connect_host" = "0.0.0.0" ]; then
        rest_connect_host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo localhost)"
    fi

    local postgres_listen_host="${POSTGRESQL_LISTEN_HOST:-0.0.0.0}"
    local postgres_port="${POSTGRESQL_PORT:-5432}"
    local postgres_connect_host="${POSTGRESQL_CONNECT_HOST:-${rest_connect_host}}"

    local archive_mode="off"
    local archive_command=""
    if [ "${PGBACKREST_ENABLE:-false}" = "true" ] && [ "${PGBACKREST_ARCHIVE_ENABLE:-true}" = "true" ]; then
        archive_mode="on"
        local archive_extra=""
        if [ -n "${PGBACKREST_ARCHIVE_COMMAND_EXTRA:-}" ]; then
            archive_extra=" ${PGBACKREST_ARCHIVE_COMMAND_EXTRA}"
        fi
        local clean_env_cmd
        clean_env_cmd="$(generate_clean_env_command)"
        archive_command="$clean_env_cmd pgbackrest --config=/etc/pgbackrest.conf --stanza=${PGBACKREST_STANZA:-default} archive-push %p${archive_extra}"
    fi

    local -a patroni_pg_hba_entries=(
        "local all postgres trust"
        "local all all md5"
        "host replication replicator 0.0.0.0/0 md5"
        "host all all 0.0.0.0/0 md5"
    )

    declare -A patroni_pg_hba_seen=(
        ["local all postgres trust"]=1
        ["local all all md5"]=1
        ["host replication replicator 0.0.0.0/0 md5"]=1
        ["host all all 0.0.0.0/0 md5"]=1
    )

    local custom_hba_entries=()
    collect_custom_pg_hba_entries custom_hba_entries

    if [ ${#custom_hba_entries[@]} -gt 0 ]; then
        for entry in "${custom_hba_entries[@]}"; do
            local index="${entry%%|*}"
            local value="${entry#*|}"

            if [ -n "${patroni_pg_hba_seen[$value]:-}" ]; then
                log_debug "Skipping duplicate Patroni pg_hba rule from PG_HBA_ADD_${index}"
                continue
            fi

            patroni_pg_hba_entries+=("$value")
            patroni_pg_hba_seen["$value"]=1
            log_info "Added Patroni pg_hba rule from PG_HBA_ADD_${index}"
        done
    fi

    local patroni_pg_hba_yaml
    patroni_pg_hba_yaml="$(printf '                - %s\n' "${patroni_pg_hba_entries[@]}")"

    # Generate basic Patroni configuration
    {
        cat <<EOF_HEADER
scope: ${PATRONI_SCOPE:-postgres-cluster}
name: ${PATRONI_NAME:-postgres-node-1}
restapi:
    listen: ${rest_listen_host}:${rest_port}
    connect_address: ${rest_connect_host}:${rest_port}
etcd3:
    host: ${ETCD_HOST:-localhost}
    port: ${ETCD_PORT:-2379}
watchdog:
    mode: ${PATRONI_WATCHDOG_MODE:-off}
    device: ${PATRONI_WATCHDOG_DEVICE:-/dev/watchdog}
    safety_margin: ${PATRONI_WATCHDOG_SAFETY_MARGIN:-5}
bootstrap:
    dcs:
        ttl: ${PATRONI_TTL:-30}
        loop_wait: ${PATRONI_LOOP_WAIT:-10}
        retry_timeout: ${PATRONI_RETRY_TIMEOUT:-10}
        maximum_lag_on_failover: ${PATRONI_MAX_LAG:-1048576}
        postgresql:
            use_pg_rewind: ${PATRONI_USE_PG_REWIND:-true}
            use_slots: ${PATRONI_USE_SLOTS:-true}
            parameters:
                wal_level: replica
                hot_standby: "on"
                logging_collector: "on"
                max_wal_senders: ${PATRONI_MAX_WAL_SENDERS:-10}
                max_replication_slots: ${PATRONI_MAX_REPLICATION_SLOTS:-10}
                wal_keep_segments: ${PATRONI_WAL_KEEP_SEGMENTS:-8}
                archive_mode: "${archive_mode}"
                archive_timeout: ${ARCHIVE_TIMEOUT:-1800s}
                archive_command: "${archive_command}"
            pg_hba:
EOF_HEADER
        printf '%s' "$patroni_pg_hba_yaml"
        cat <<EOF_FOOTER
postgresql:
    listen: ${postgres_listen_host}:${postgres_port}
    connect_address: ${postgres_connect_host}:${postgres_port}
    data_dir: ${data_dir}
    config_dir: ${data_dir}
    user: postgres
    pgpass: /tmp/pgpass
    authentication:
        replication:
            username: ${PATRONI_REPLICATION_USER:-replicator}
            password: ${PATRONI_REPLICATION_PASSWORD:-replicator_password}
        superuser:
            username: ${POSTGRES_USER:-postgres}
            password: ${POSTGRES_PASSWORD:-postgres_password}
    parameters:
        unix_socket_directories: '${PGRUN:-/usr/local/pgsql/run}'
        timezone: '${POSTGRESQL_TIMEZONE:-UTC}'
EOF_FOOTER
    } > "$patroni_config"

    set_secure_permissions "$patroni_config"
    log_info "Generated Patroni configuration: $patroni_config"

    # Validate the generated configuration
    if ! validate_patroni_config "$patroni_config"; then
        log_error "Generated Patroni configuration is invalid"
        log_info "Generated YAML content:"
        cat "$patroni_config" | while IFS= read -r line; do
            log_info "  $line"
        done
        return 1
    fi
}

# Apply external access configuration
apply_external_access_config() {
    log_info "Applying external access configuration"

    # Parse environment variables with defaults
    local enable_external="${EXTERNAL_ACCESS_ENABLE:-true}"
    local method="${EXTERNAL_ACCESS_METHOD:-md5}"

    # Validate authentication method
    case "$method" in
        trust|reject|md5|password|scram-sha-256) ;;
        *) 
            log_warn "Invalid EXTERNAL_ACCESS_METHOD '$method', falling back to md5"
            method="md5"
            ;;
    esac

    # Update pg_hba.conf based on configuration
    local hba_file="${PGDATA:-/usr/local/pgsql/data}/pg_hba.conf"

    if [ "$enable_external" = "true" ]; then
        # Ensure external access lines exist with correct method
        if ! grep -q "host    all             all             0.0.0.0/0" "$hba_file"; then
            echo "host    all             all             0.0.0.0/0               $method" >> "$hba_file"
        else
            sed -i "s/host    all             all             0\.0\.0\.0\/0               .*/host    all             all             0.0.0.0\/0               $method/" "$hba_file"
        fi
        if ! grep -q "host    all             all             ::/0" "$hba_file"; then
            echo "host    all             all             ::/0                    $method" >> "$hba_file"
        else
            sed -i "s/host    all             all             ::\/0                    .*/host    all             all             ::\/0                    $method/" "$hba_file"
        fi
    else
        # Remove external access lines
        sed -i '/host    all             all             0\.0\.0\.0\/0/d' "$hba_file"
        sed -i '/host    all             all             ::\/0/d' "$hba_file"
    fi

    log_info "External access configuration applied: enabled=$enable_external, method=$method"
}

# Apply custom pg_hba.conf entries based on PG_HBA_ADD_* environment variables
apply_custom_pg_hba_entries() {
    local data_dir="${PGDATA:-/usr/local/pgsql/data}"
    local hba_file="$data_dir/pg_hba.conf"
    local state_file="$data_dir/.pg_hba_env_entries"

    if [ ! -f "$hba_file" ]; then
        log_warn "pg_hba.conf not found at $hba_file; skipping PG_HBA_ADD_* entries"
        return 0
    fi

    local entries=()
    collect_custom_pg_hba_entries entries

    if [ -f "$state_file" ]; then
        log_debug "Removing previously managed PG_HBA_ADD entries from pg_hba.conf"
        while IFS= read -r previous_entry; do
            [ -z "$previous_entry" ] && continue
            remove_pg_hba_line "$hba_file" "$previous_entry"
        done < "$state_file"
    fi

    if [ ${#entries[@]} -eq 0 ]; then
        log_info "No PG_HBA_ADD_* environment variables found; cleaned up managed pg_hba entries"
        rm -f "$state_file"
        return 0
    fi

    log_info "Applying ${#entries[@]} custom pg_hba.conf entries from PG_HBA_ADD_* variables"

    local new_state_entries=()

    local tmp_file
    tmp_file="$(mktemp)"

    for entry in "${entries[@]}"; do
        local index="${entry%%|*}"
        local value="${entry#*|}"

        remove_pg_hba_line "$hba_file" "$value"
        new_state_entries+=("$value")
        log_info "Prepared pg_hba.conf rule from PG_HBA_ADD_${index}"
    done

    if [ ${#new_state_entries[@]} -gt 0 ]; then
        printf '%s\n' "${new_state_entries[@]}" > "$tmp_file"
        printf '\n' >> "$tmp_file"
    fi

    cat "$hba_file" >> "$tmp_file"
    mv "$tmp_file" "$hba_file"

    printf '%s\n' "${new_state_entries[@]}" > "$state_file"
    set_secure_permissions "$state_file"
    set_secure_permissions "$hba_file"
}

# Execute main function
main "$@"
