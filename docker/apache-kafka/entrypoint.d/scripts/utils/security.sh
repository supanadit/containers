#!/bin/bash
# security.sh - Security hardening and permission management utilities

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

KAFKA_USER="${KAFKA_USER:-kafka}"
KAFKA_GROUP="${KAFKA_GROUP:-kafka}"

set_secure_permissions() {
    local target_path="$1"

    log_debug "Setting secure permissions on: $target_path"

    if [ ! -e "$target_path" ]; then
        log_error "Path does not exist: $target_path"
        return 1
    fi

    if [ -d "$target_path" ]; then
        chmod 755 "$target_path"
        log_debug "Set directory permissions 755 on: $target_path"
    else
        chmod 644 "$target_path"
        log_debug "Set file permissions 644 on: $target_path"
    fi

    if id "$KAFKA_USER" >/dev/null 2>&1; then
        chown "$KAFKA_USER:$KAFKA_GROUP" "$target_path"
        log_debug "Set ownership to $KAFKA_USER:$KAFKA_GROUP on: $target_path"
    else
        log_warn "Kafka user $KAFKA_USER does not exist, skipping ownership change"
    fi
}

drop_privileges() {
    local target_user="${1:-$KAFKA_USER}"

    log_debug "Dropping privileges to user: $target_user"

    if [ "$(id -u)" -eq 0 ]; then
        if ! id "$target_user" >/dev/null 2>&1; then
            log_error "Target user does not exist: $target_user"
            return 1
        fi

        log_info "Dropping privileges from root to $target_user"
        exec su -c "$0 $*" "$target_user"
    else
        log_debug "Already running as non-root user: $(id -u)"
    fi
}

validate_security_context() {
    local exit_code=0

    log_debug "Validating security context"

    local current_uid
    current_uid=$(id -u)

    if [ "$current_uid" -eq 0 ]; then
        log_info "Running as root - this may be required for initialization"
    else
        log_info "Running as user: $(id -un) (uid: $current_uid)"
    fi

    local sensitive_vars=("KAFKA_SASL_JAAS_CONFIG" "KAFKA_SSL_KEYSTORE_PASSWORD" "KAFKA_SSL_TRUSTSTORE_PASSWORD" "KAFKA_SSL_KEY_PASSWORD")
    for var in "${sensitive_vars[@]}"; do
        if [ -n "${!var:-}" ]; then
            log_warn "Sensitive environment variable is set: $var"
            audit_security_event "sensitive_var_set" "$var"
        fi
    done

    local config_file="/opt/kafka/config/server.properties"
    if [ -f "$config_file" ]; then
        local perms
        perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "unknown")
        if [ "$perms" = "777" ] || [ "$perms" = "666" ]; then
            log_error "Insecure permissions on config file: $config_file ($perms)"
            audit_security_event "insecure_permissions" "$config_file:$perms"
            exit_code=1
        fi
    fi

    return "$exit_code"
}

audit_security_event() {
    local event_type="$1"
    local details="$2"
    local timestamp
    timestamp=$(get_timestamp)
    echo "[$timestamp] [SECURITY] [$event_type] $details" >&2
}

create_secure_temp_file() {
    local prefix="${1:-tmp}"
    local temp_file
    temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")
    chmod 600 "$temp_file"
    log_debug "Created secure temporary file: $temp_file"
    echo "$temp_file"
}

create_secure_temp_dir() {
    local prefix="${1:-tmp}"
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    chmod 700 "$temp_dir"
    log_debug "Created secure temporary directory: $temp_dir"
    echo "$temp_dir"
}

secure_cleanup() {
    local path="$1"
    if [ -e "$path" ]; then
        if command -v shred >/dev/null 2>&1; then
            shred -u "$path" 2>/dev/null || rm -f "$path"
        else
            rm -f "$path"
        fi
        log_debug "Securely cleaned up: $path"
    fi
}

validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"

    if [ "${#password}" -lt "$min_length" ]; then
        log_error "Password too short (minimum $min_length characters)"
        return 1
    fi

    if ! [[ "$password" =~ [A-Z] ]] || ! [[ "$password" =~ [a-z] ]] || ! [[ "$password" =~ [0-9] ]]; then
        log_error "Password must contain uppercase, lowercase, and numeric characters"
        return 1
    fi

    return 0
}

generate_secure_password() {
    local length="${1:-16}"

    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif command -v pwgen >/dev/null 2>&1; then
        pwgen -s "$length" 1
    else
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    fi
}

is_container_environment() {
    if [ -f /.dockerenv ] || [ -n "${container:-}" ] || grep -q "docker\|containerd\|podman" /proc/1/cgroup 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

apply_container_security() {
    log_debug "Applying container-specific security measures"
    ulimit -c 0
    umask 0027
    if [ "$(id -u)" -eq 0 ]; then
        log_info "Running as root - consider dropping capabilities in Docker"
    fi
    audit_security_event "container_security_applied" "umask=0027,core_dumps=disabled"
}

export -f set_secure_permissions
export -f drop_privileges
export -f validate_security_context
export -f audit_security_event
export -f create_secure_temp_file
export -f create_secure_temp_dir
export -f secure_cleanup
export -f validate_password_strength
export -f generate_secure_password
export -f is_container_environment
export -f apply_container_security
