#!/bin/bash
# security.sh - Security hardening and permission management utilities
# Provides security functions for container hardening

# Set strict error handling
set -euo pipefail

# Source logging utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

# Default user and group for PostgreSQL
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_GROUP="${POSTGRES_GROUP:-postgres}"

# Set secure permissions on files and directories
set_secure_permissions() {
    local target_path="$1"

    log_debug "Setting secure permissions on: $target_path"

    if [ ! -e "$target_path" ]; then
        log_error "Path does not exist: $target_path"
        return 1
    fi

    # Determine if it's a file or directory
    if [ -d "$target_path" ]; then
        # Directory permissions: 755 (owner rwx, group rx, others rx)
        chmod 755 "$target_path"
        log_debug "Set directory permissions 755 on: $target_path"
    else
        # File permissions: 644 (owner rw, group r, others r)
        chmod 644 "$target_path"
        log_debug "Set file permissions 644 on: $target_path"
    fi

    # Set ownership to postgres user if it exists
    if id "$POSTGRES_USER" >/dev/null 2>&1; then
        chown "$POSTGRES_USER:$POSTGRES_GROUP" "$target_path"
        log_debug "Set ownership to $POSTGRES_USER:$POSTGRES_GROUP on: $target_path"
    else
        log_warn "PostgreSQL user $POSTGRES_USER does not exist, skipping ownership change"
    fi
}

# Drop privileges from root to postgres user
drop_privileges() {
    local target_user="${1:-$POSTGRES_USER}"

    log_debug "Dropping privileges to user: $target_user"

    # Check if we're running as root
    if [ "$(id -u)" -eq 0 ]; then
        # Check if target user exists
        if ! id "$target_user" >/dev/null 2>&1; then
            log_error "Target user does not exist: $target_user"
            return 1
        fi

        # Drop privileges
        log_info "Dropping privileges from root to $target_user"
        exec su -c "$0 $*" "$target_user"
    else
        log_debug "Already running as non-root user: $(id -u)"
    fi
}

# Validate current security context
validate_security_context() {
    local exit_code=0

    log_debug "Validating security context"

    # Check if running as root (may be necessary for initialization)
    local current_uid
    current_uid=$(id -u)

    if [ "$current_uid" -eq 0 ]; then
        log_info "Running as root - this may be required for initialization"
    else
        log_info "Running as user: $(id -un) (uid: $current_uid)"
    fi

    # Check for dangerous environment variables
    local dangerous_vars=("POSTGRES_PASSWORD" "PATRONI_SUPERUSER_PASSWORD")
    for var in "${dangerous_vars[@]}"; do
        if [ -n "${!var:-}" ]; then
            log_warn "Sensitive environment variable is set: $var"
            audit_security_event "sensitive_var_set" "$var"
        fi
    done

    # Check file permissions on sensitive files
    local sensitive_files=("${PGDATA:-}/postgresql.conf" "${PGDATA:-}/pg_hba.conf")
    for file in "${sensitive_files[@]}"; do
        if [ -f "$file" ]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")
            if [ "$perms" = "777" ] || [ "$perms" = "666" ]; then
                log_error "Insecure permissions on sensitive file: $file ($perms)"
                audit_security_event "insecure_permissions" "$file:$perms"
                exit_code=1
            fi
        fi
    done

    return "$exit_code"
}

# Audit security-related events
audit_security_event() {
    local event_type="$1"
    local details="$2"
    local timestamp
    timestamp=$(get_timestamp)

    # Log to stderr for security events
    echo "[$timestamp] [SECURITY] [$event_type] $details" >&2

    # Could also write to a security log file if needed
    # echo "[$timestamp] [$event_type] $details" >> /var/log/postgresql/security.log
}

# Secure temporary file creation
create_secure_temp_file() {
    local prefix="${1:-tmp}"
    local temp_file

    # Create temporary file with secure permissions
    temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")
    chmod 600 "$temp_file"

    log_debug "Created secure temporary file: $temp_file"
    echo "$temp_file"
}

# Secure temporary directory creation
create_secure_temp_dir() {
    local prefix="${1:-tmp}"
    local temp_dir

    # Create temporary directory with secure permissions
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    chmod 700 "$temp_dir"

    log_debug "Created secure temporary directory: $temp_dir"
    echo "$temp_dir"
}

# Clean up temporary files securely
secure_cleanup() {
    local path="$1"

    if [ -e "$path" ]; then
        # Use shred if available for secure deletion
        if command -v shred >/dev/null 2>&1; then
            shred -u "$path" 2>/dev/null || rm -f "$path"
        else
            rm -f "$path"
        fi
        log_debug "Securely cleaned up: $path"
    fi
}

# Validate password strength (basic check)
validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"

    # Check minimum length
    if [ "${#password}" -lt "$min_length" ]; then
        log_error "Password too short (minimum $min_length characters)"
        return 1
    fi

    # Check for at least one uppercase, lowercase, and digit
    if ! [[ "$password" =~ [A-Z] ]] || ! [[ "$password" =~ [a-z] ]] || ! [[ "$password" =~ [0-9] ]]; then
        log_error "Password must contain uppercase, lowercase, and numeric characters"
        return 1
    fi

    return 0
}

# Generate secure random password
generate_secure_password() {
    local length="${1:-16}"

    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif command -v pwgen >/dev/null 2>&1; then
        pwgen -s "$length" 1
    else
        # Fallback to /dev/urandom
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    fi
}

# Check if running in a container environment
is_container_environment() {
    # Check for common container indicators
    if [ -f /.dockerenv ] || [ -n "${container:-}" ] || grep -q "docker\|containerd\|podman" /proc/1/cgroup 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Apply container-specific security measures
apply_container_security() {
    log_debug "Applying container-specific security measures"

    # Disable core dumps (common in containers)
    ulimit -c 0

    # Set restrictive umask
    umask 0027

    # Remove dangerous capabilities if running as root
    if [ "$(id -u)" -eq 0 ]; then
        # Note: This would require cap_drop in Docker, but we can log the intent
        log_info "Running as root - consider dropping capabilities in Docker"
    fi

    audit_security_event "container_security_applied" "umask=0027,core_dumps=disabled"
}

# Export functions for use by other scripts
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