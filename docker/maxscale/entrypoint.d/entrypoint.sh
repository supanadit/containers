#!/bin/bash
# entrypoint.sh - Main container orchestrator for MaxScale
# Coordinates all modular scripts for MaxScale container initialization and runtime

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

SCRIPT_VERSION="1.0.0"

# Default directories
export MAXSCALE_CONFIG_DIR="${MAXSCALE_CONFIG_DIR:-/var/lib/maxscale}"
export MAXSCALE_DATA_DIR="${MAXSCALE_DATA_DIR:-/var/lib/maxscale/data}"
export MAXSCALE_LOG_DIR="${MAXSCALE_LOG_DIR:-/var/log/maxscale}"

# MaxScale configuration
export MAXSCALE_SERVICE_USER="${MAXSCALE_SERVICE_USER:-maxscale}"
export MAXSCALE_SERVICE_PASSWORD="${MAXSCALE_SERVICE_PASSWORD:-maxscale}"
export MAXSCALE_SERVICE_READWRITE_ROUTES="${MAXSCALE_SERVICE_READWRITE_ROUTES:-localhost:3306}"
export MAXSCALE_SERVICE_READCONN_ROUTES="${MAXSCALE_SERVICE_READCONN_ROUTES:-localhost:3306}"
export MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS="${MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS:-localhost:3306}"
export MAXSCALE_THREADS="${MAXSCALE_THREADS:-auto}"

main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"

    log_info "MaxScale Container Entrypoint v$SCRIPT_VERSION"
    log_environment

    setup_directories
    generate_config
    validate_config
    wait_for_backends

    log_script_end "entrypoint.sh"

    log_info "Starting MaxScale"
    export PATH="/usr/bin:$PATH"
    exec gosu maxscale maxscale -f /etc/maxscale.cnf.d/generated.cnf
}

setup_directories() {
    log_info "Setting up MaxScale directories"

    mkdir -p "$MAXSCALE_CONFIG_DIR" "$MAXSCALE_DATA_DIR" "$MAXSCALE_LOG_DIR" /etc/maxscale.cnf.d

    chown -R maxscale:maxscale "$MAXSCALE_CONFIG_DIR" "$MAXSCALE_DATA_DIR" "$MAXSCALE_LOG_DIR" /etc/maxscale.cnf.d /var/log/maxscale

    log_info "  - Config directory: $MAXSCALE_CONFIG_DIR"
    log_info "  - Data directory: $MAXSCALE_DATA_DIR"
    log_info "  - Log directory: $MAXSCALE_LOG_DIR"
}

generate_config() {
    log_info "Generating MaxScale configuration"

    local server_names
    server_names=$(get_server_names)

    cat > /etc/maxscale.cnf.d/generated.cnf << MAXSCALE_CONFIG
[maxscale]
threads=${MAXSCALE_THREADS}
admin_auth=true
admin_enabled=true

[Read-Write-Service]
type=service
router=readwritesplit
servers=${server_names}
user=${MAXSCALE_SERVICE_USER}
password=${MAXSCALE_SERVICE_PASSWORD}

[Read-Connection-Service]
type=service
router=readconnroute
servers=${server_names}
router_options=slave
user=${MAXSCALE_SERVICE_USER}
password=${MAXSCALE_SERVICE_PASSWORD}

[MariaDB-Monitor]
type=monitor
module=mariadbmon
servers=${server_names}
monitor_interval=10s
switchover_timeout=3600s
user=${MAXSCALE_SERVICE_USER}
password=${MAXSCALE_SERVICE_PASSWORD}

$(parse_server_definitions)

[Read-Write-Listener]
type=listener
service=Read-Write-Service
protocol=MariaDB
port=3306

[Read-Connection-Listener]
type=listener
service=Read-Connection-Service
protocol=MariaDB
port=3308
MAXSCALE_CONFIG

    log_info "Configuration generated successfully"
}

parse_server_definitions() {
    local index=1
    IFS=',' read -ra ADDR <<< "${MAXSCALE_SERVICE_READWRITE_ROUTES}"
    for server in "${ADDR[@]}"; do
        local host_port
        IFS=':' read -ra host_port <<< "$server"
        local host="${host_port[0]}"
        local port="${host_port[1]:-3306}"
        echo "[server${index}]"
        echo "type=server"
        echo "address=${host}"
        echo "port=${port}"
        echo ""
        ((index++))
    done
}

get_server_names() {
    local index=1
    local names=""
    IFS=',' read -ra ADDR <<< "${MAXSCALE_SERVICE_READWRITE_ROUTES}"
    for server in "${ADDR[@]}"; do
        if [ -n "$names" ]; then
            names="${names},server${index}"
        else
            names="server${index}"
        fi
        ((index++))
    done
    echo "$names"
}

validate_config() {
    log_info "Validating MaxScale configuration"

    if [ ! -f /etc/maxscale.cnf.d/generated.cnf ]; then
        log_error "Configuration file not found"
        exit 1
    fi

    log_info "Configuration validation passed"
}

wait_for_backends() {
    log_info "Waiting for backend servers to be available"

    local max_wait=60
    local interval=5
    local waited=0

    IFS=',' read -ra SERVERS <<< "${MAXSCALE_SERVICE_READWRITE_ROUTES}"
    for server in "${SERVERS[@]}"; do
        local host_port
        IFS=':' read -ra host_port <<< "$server"
        local host="${host_port[0]}"
        local port="${host_port[1]:-3306}"

        log_info "Checking backend server: $host:$port"

        while [ $waited -lt $max_wait ]; do
            if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
                log_info "Backend $host:$port is reachable"
                break
            else
                log_info "Backend $host:$port not ready, waiting... (${waited}s/${max_wait}s)"
                sleep $interval
                ((waited+=$interval))
            fi
        done

        if [ $waited -ge $max_wait ]; then
            log_warn "Backend $host:$port did not become available within ${max_wait}s, continuing anyway"
        fi
    done

    log_info "Backend availability check completed"
}

main "$@"