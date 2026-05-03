#!/bin/bash
# security.sh - Security utilities for MariaDB container

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

# Generate secure random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d '/+=' | head -c "$length"
}

# Secure password file creation
secure_file() {
    local file="$1"
    local owner="${2:-mysql}"
    local perms="${3:-0600}"

    if [ -f "$file" ]; then
        chmod "$perms" "$file"
        chown "$owner:$owner" "$file"
    fi
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    local min_length="${2:-12}"

    if [ ${#password} -lt "$min_length" ]; then
        log_warn "Password is too short (minimum $min_length characters)"
        return 1
    fi

    return 0
}

# Setup SSL/TLS
setup_ssl() {
    if [ "${MARIADB_SSL_ENABLE:-false}" != "true" ]; then
        log_info "SSL/TLS is not enabled"
        return 0
    fi

    log_info "Setting up SSL/TLS"

    local ssl_dir="${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}"
    local cert_dir="/var/lib/mysql/ssl"

    mkdir -p "$cert_dir"
    chown mysql:mysql "$cert_dir"
    chmod 0700 "$cert_dir"

    # Generate self-signed certificate if not provided
    if [ ! -f "$cert_dir/server.crt" ]; then
        log_info "Generating self-signed SSL certificate"
        openssl req -new -x509 -nodes -days 365 \
            -subj "/CN=MariaDB/O=MariaDB Foundation/C=US" \
            -keyout "$cert_dir/server.key" \
            -out "$cert_dir/server.crt" \
            2>/dev/null

        chown mysql:mysql "$cert_dir/server.key" "$cert_dir/server.crt"
        chmod 0600 "$cert_dir/server.key"
    fi

    log_info "SSL/TLS configuration completed"
}

# Setup replication user
setup_replication_user() {
    if [ "${MARIADB_REPLICATION_ENABLE:-false}" != "true" ]; then
        return 0
    fi

    log_info "Setting up replication user"

    local replication_user="${MARIADB_REPLICATION_USER:-repl}"
    local replication_password="${MARIADB_REPLICATION_PASSWORD:-}"

    if [ -z "$replication_password" ]; then
        log_warn "Replication password not set, skipping replication user setup"
        return 0
    fi

    mariadb -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "
        CREATE USER IF NOT EXISTS '$replication_user'@'%' IDENTIFIED BY '$replication_password';
        GRANT REPLICATION SLAVE ON *.* TO '$replication_user'@'%';
        GRANT FILE ON *.* TO '$replication_user'@'%';
        FLUSH PRIVILEGES;
    " 2>/dev/null || true

    log_info "Replication user setup completed"
}

# Secure mysql installation
secure_installation() {
    log_info "Running mysql_secure_installation tasks"

    local mysql_root_password="${MARIADB_ROOT_PASSWORD:-}"

    # Remove anonymous users
    mariadb -u root -p"${mysql_root_password}" -e "
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        FLUSH PRIVILEGES;
    " 2>/dev/null || true

    log_info "Security tasks completed"
}