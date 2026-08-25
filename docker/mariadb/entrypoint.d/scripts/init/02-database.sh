#!/bin/bash
# 02-database.sh - Database initialization for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

log_script_start "02-database.sh"

export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/opt/containers/data}"
export MARIADB_RUN_DIR="${MARIADB_RUN_DIR:-/opt/containers/run}"

setup_initial_database() {
    log_info "Setting up initial database configuration"

    if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
        log_info "Initializing MariaDB data directory at $MARIADB_DATA_DIR"

        mkdir -p "$MARIADB_DATA_DIR"
        chown -R mysql:mysql "$MARIADB_DATA_DIR"

        mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR" --rpm

        log_info "Database initialized successfully"
    else
        log_info "Database already initialized, skipping initialization"
    fi

    local init_sql="/tmp/init.sql"
    local socket="${MARIADB_RUN_DIR}/mysqld.sock"

    cat > "$init_sql" << EOF
-- Set root password if provided
EOF

    if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" >> "$init_sql"
    elif [ "${MARIADB_ALLOW_EMPTY_PASSWORD:-no}" != "yes" ]; then
        log_warn "No root password set and empty passwords not allowed"
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '';" >> "$init_sql"
    fi

    if [ -n "${MARIADB_DATABASE:-}" ]; then
        echo "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;" >> "$init_sql"
    fi

    if [ -n "${MARIADB_USER:-}" ] && [ -n "${MARIADB_PASSWORD:-}" ]; then
        echo "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';" >> "$init_sql"
        if [ -n "${MARIADB_DATABASE:-}" ]; then
            echo "GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';" >> "$init_sql"
        fi
    fi

    if [ -n "${MAXSCALE_SERVICE_USER:-}" ] && [ -n "${MAXSCALE_SERVICE_PASSWORD:-}" ]; then
        log_info "Creating MaxScale service user: ${MAXSCALE_SERVICE_USER}"
        echo "CREATE USER IF NOT EXISTS '${MAXSCALE_SERVICE_USER}'@'%' IDENTIFIED BY '${MAXSCALE_SERVICE_PASSWORD}';" >> "$init_sql"
        echo "GRANT SELECT, RELOAD, PROCESS, SUPER, REPLICATION CLIENT, REPLICATION SLAVE, SLAVE MONITOR, SHOW DATABASES ON *.* TO '${MAXSCALE_SERVICE_USER}'@'%';" >> "$init_sql"
    fi

    echo "FLUSH PRIVILEGES;" >> "$init_sql"

    mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --skip-networking --socket="$socket" &
    local pid=$!

    sleep 5

    mariadb --socket="$socket" -u root < "$init_sql"

    kill $pid
    wait $pid 2>/dev/null || true

    rm -f "$init_sql" "$socket"

    log_info "Initial database setup completed"
}

setup_replication_user() {
    log_info "Replication user setup skipped (not implemented)"
}

secure_installation() {
    log_info "Secure installation skipped (handled by initialization)"
}

setup_initial_database
setup_replication_user
secure_installation

log_script_end "02-database.sh"