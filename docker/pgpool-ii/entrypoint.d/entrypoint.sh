#!/bin/bash
# entrypoint.sh - PgPool-II container orchestrator
# Manages PgPool-II configuration and startup with multiple PostgreSQL backends

# Set strict error handling
set -euo pipefail

# Script version
SCRIPT_VERSION="1.0.0"

# Default configuration
export PGPOOL_PORT="${PGPOOL_PORT:-5432}"
export PGPOOL_PCP_PORT="${PGPOOL_PCP_PORT:-9898}"
export PGPOOL_CONFIG_DIR="${PGPOOL_CONFIG_DIR:-/usr/local/pgpool/etc}"
export PGPOOL_LOG_DIR="${PGPOOL_LOG_DIR:-/var/log/pgpool}"
export PGPOOL_RUN_DIR="${PGPOOL_RUN_DIR:-/var/run/pgpool}"
export PGPOOL_USER="${PGPOOL_USER:-postgres}"

# PostgreSQL backend configuration
export PGPOOL_BACKENDS="${PGPOOL_BACKENDS:-}"
export PGPOOL_BACKEND_WEIGHTS="${PGPOOL_BACKEND_WEIGHTS:-}"
export PGPOOL_BACKEND_FLAGS="${PGPOOL_BACKEND_FLAGS:-}"

# Patroni integration
export PGPOOL_PATRONI_ENDPOINTS="${PGPOOL_PATRONI_ENDPOINTS:-}"
export PGPOOL_PATRONI_TIMEOUT="${PGPOOL_PATRONI_TIMEOUT:-10}"

# Pool configuration
export PGPOOL_NUM_INIT_CHILDREN="${PGPOOL_NUM_INIT_CHILDREN:-32}"
export PGPOOL_MAX_POOL="${PGPOOL_MAX_POOL:-4}"
export PGPOOL_CHILD_LIFE_TIME="${PGPOOL_CHILD_LIFE_TIME:-300}"
export PGPOOL_CONNECTION_LIFE_TIME="${PGPOOL_CONNECTION_LIFE_TIME:-0}"
export PGPOOL_CHILD_MAX_CONNECTIONS="${PGPOOL_CHILD_MAX_CONNECTIONS:-0}"

# Load balancing
export PGPOOL_LOAD_BALANCE_MODE="${PGPOOL_LOAD_BALANCE_MODE:-on}"
export PGPOOL_IGNORE_LEADING_WHITE_SPACE="${PGPOOL_IGNORE_LEADING_WHITE_SPACE:-on}"

# Authentication
export PGPOOL_ENABLE_POOL_HBA="${PGPOOL_ENABLE_POOL_HBA:-off}"
export PGPOOL_POOL_PASSWD="${PGPOOL_POOL_PASSWD:-pool_passwd}"
export PGPOOL_BACKEND_USER="${PGPOOL_BACKEND_USER:-postgres}"
export PGPOOL_BACKEND_PASSWORD="${PGPOOL_BACKEND_PASSWORD:-}"

# Health check
export PGPOOL_HEALTH_CHECK_TIMEOUT="${PGPOOL_HEALTH_CHECK_TIMEOUT:-20}"
export PGPOOL_HEALTH_CHECK_PERIOD="${PGPOOL_HEALTH_CHECK_PERIOD:-0}"
export PGPOOL_HEALTH_CHECK_USER="${PGPOOL_HEALTH_CHECK_USER:-$PGPOOL_BACKEND_USER}"
export PGPOOL_HEALTH_CHECK_PASSWORD="${PGPOOL_HEALTH_CHECK_PASSWORD:-}"
export PGPOOL_HEALTH_CHECK_DATABASE="${PGPOOL_HEALTH_CHECK_DATABASE:-}"
export PGPOOL_HEALTH_CHECK_MAX_RETRIES="${PGPOOL_HEALTH_CHECK_MAX_RETRIES:-0}"
export PGPOOL_HEALTH_CHECK_RETRY_DELAY="${PGPOOL_HEALTH_CHECK_RETRY_DELAY:-0}"

# Connection timeout
export PGPOOL_CONNECT_TIMEOUT="${PGPOOL_CONNECT_TIMEOUT:-10000}"

# Streaming replication check
export PGPOOL_SR_CHECK_PERIOD="${PGPOOL_SR_CHECK_PERIOD:-10}"
export PGPOOL_SR_CHECK_USER="${PGPOOL_SR_CHECK_USER:-$PGPOOL_BACKEND_USER}"
export PGPOOL_SR_CHECK_PASSWORD="${PGPOOL_SR_CHECK_PASSWORD:-}"
export PGPOOL_SR_CHECK_DATABASE="${PGPOOL_SR_CHECK_DATABASE:-postgres}"
export PGPOOL_DELAY_THRESHOLD="${PGPOOL_DELAY_THRESHOLD:-0}"
export PGPOOL_DELAY_THRESHOLD_BY_TIME="${PGPOOL_DELAY_THRESHOLD_BY_TIME:-0}"
export PGPOOL_PREFER_LOWER_DELAY_STANDBY="${PGPOOL_PREFER_LOWER_DELAY_STANDBY:-off}"
export PGPOOL_LOG_STANDBY_DELAY="${PGPOOL_LOG_STANDBY_DELAY:-if_over_threshold}"

# Master slave mode
export PGPOOL_MASTER_SLAVE_MODE="${PGPOOL_MASTER_SLAVE_MODE:-on}"
export PGPOOL_MASTER_SLAVE_SUB_MODE="${PGPOOL_MASTER_SLAVE_SUB_MODE:-stream}"

# Connection pooling
export PGPOOL_CONNECTION_CACHE="${PGPOOL_CONNECTION_CACHE:-on}"
export PGPOOL_RESET_QUERY_LIST="${PGPOOL_RESET_QUERY_LIST:-'ABORT; DISCARD ALL'}"

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >&2
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2
}

log_debug() {
    if [ "${PGPOOL_DEBUG:-false}" = "true" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >&2
    fi
}

# Validate environment
validate_environment() {
    log_info "Validating environment configuration"
    
    if [ -z "$PGPOOL_BACKENDS" ]; then
        log_error "PGPOOL_BACKENDS environment variable is required"
        log_error "Example: PGPOOL_BACKENDS='172.10.10.5:5432,172.10.10.6:5432,172.10.10.7:5432'"
        exit 1
    fi
    
    # Validate Patroni configuration
    if [ -n "${PGPOOL_PATRONI_ENDPOINTS:-}" ]; then
        log_info "Patroni integration enabled"
        if ! command -v curl >/dev/null 2>&1; then
            log_error "curl is required for Patroni integration but not found"
            exit 1
        fi
        if ! command -v jq >/dev/null 2>&1; then
            log_error "jq is required for Patroni integration but not found"
            exit 1
        fi
    fi
    
    # Validate pgpool-II installation
    if ! command -v pgpool >/dev/null 2>&1; then
        log_error "pgpool command not found. Please ensure pgpool-II is properly installed."
        exit 1
    fi
    
    log_info "Environment validation completed"
}

# Create necessary directories
setup_directories() {
    log_info "Setting up directories"
    
    local dirs=(
        "$PGPOOL_CONFIG_DIR"
        "$PGPOOL_LOG_DIR" 
        "$PGPOOL_RUN_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_debug "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    # Set proper ownership
    chown -R "$PGPOOL_USER:$PGPOOL_USER" "$PGPOOL_CONFIG_DIR" "$PGPOOL_LOG_DIR" "$PGPOOL_RUN_DIR" 2>/dev/null || true
    
    log_info "Directory setup completed"
}

# Parse backend configuration from environment
parse_backends() {
    log_info "Parsing backend configuration"
    
    # Split backends by comma
    IFS=',' read -ra BACKEND_ARRAY <<< "$PGPOOL_BACKENDS"
    
    # Parse weights if provided
    if [ -n "${PGPOOL_BACKEND_WEIGHTS:-}" ]; then
        IFS=',' read -ra WEIGHT_ARRAY <<< "$PGPOOL_BACKEND_WEIGHTS"
    else
        # Default equal weights
        WEIGHT_ARRAY=()
        for ((i=0; i<${#BACKEND_ARRAY[@]}; i++)); do
            WEIGHT_ARRAY[i]=1
        done
    fi
    
    # Parse flags if provided
    if [ -n "${PGPOOL_BACKEND_FLAGS:-}" ]; then
        IFS=',' read -ra FLAG_ARRAY <<< "$PGPOOL_BACKEND_FLAGS"
    else
        # Default flags based on master slave mode
        FLAG_ARRAY=()
        for ((i=0; i<${#BACKEND_ARRAY[@]}; i++)); do
            if [ "$PGPOOL_MASTER_SLAVE_MODE" = "on" ] && [ $i -eq 0 ]; then
                FLAG_ARRAY[i]="ALLOW_TO_FAILOVER"
            elif [ "$PGPOOL_MASTER_SLAVE_MODE" = "on" ]; then
                FLAG_ARRAY[i]="DISALLOW_TO_FAILOVER"
            else
                FLAG_ARRAY[i]="ALLOW_TO_FAILOVER"
            fi
        done
    fi
    
    log_info "Found ${#BACKEND_ARRAY[@]} backend(s):"
    for ((i=0; i<${#BACKEND_ARRAY[@]}; i++)); do
        log_info "  Backend $i: ${BACKEND_ARRAY[i]} (weight: ${WEIGHT_ARRAY[i]:-1}, flag: ${FLAG_ARRAY[i]:-ALLOW_TO_FAILOVER})"
    done
}

# Generate pool_hba.conf configuration
generate_pool_hba_config() {
    log_info "Generating pool_hba.conf configuration"
    
    local hba_file="$PGPOOL_CONFIG_DIR/pool_hba.conf"
    
    cat > "$hba_file" << EOF
# pool_hba.conf configuration generated by container entrypoint
# Generated on: $(date)

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Allow all connections (modify as needed for production)
local   all             all                                     trust
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
EOF
    
    log_info "pool_hba.conf configuration generated at: $hba_file"
}

# Generate pool_passwd file
generate_pool_passwd() {
    log_info "Generating pool_passwd file"
    
    local passwd_file="$PGPOOL_CONFIG_DIR/pool_passwd"
    
    # Check if PGPOOL_BACKEND_PASSWORD is provided
    if [ -z "${PGPOOL_BACKEND_PASSWORD:-}" ]; then
        log_warn "PGPOOL_BACKEND_PASSWORD not set, skipping pool_passwd generation"
        return
    fi
    
    # Generate MD5 hash (PostgreSQL format: md5(password + username))
    local hash
    hash=$(echo -n "${PGPOOL_BACKEND_PASSWORD}${PGPOOL_HEALTH_CHECK_USER}" | md5sum | cut -d' ' -f1)
    
    # Create pool_passwd file
    echo "${PGPOOL_HEALTH_CHECK_USER}:md5${hash}" > "$passwd_file"
    
    # Set proper permissions
    chmod 600 "$passwd_file"
    chown "$PGPOOL_USER:$PGPOOL_USER" "$passwd_file" 2>/dev/null || true
    
    log_info "pool_passwd file generated at: $passwd_file"
}

# Generate follow_master_command script for Patroni integration
generate_follow_master_command() {
    log_info "Generating follow_master_command script for Patroni"
    
    local script_file="$PGPOOL_CONFIG_DIR/follow_master.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# follow_master.sh - Determine the current primary from Patroni cluster
# This script queries Patroni REST API endpoints to find the leader

set -euo pipefail

# Configuration from environment
PATRONI_ENDPOINTS="${PGPOOL_PATRONI_ENDPOINTS:-}"
TIMEOUT="${PGPOOL_PATRONI_TIMEOUT:-10}"

# Check if endpoints are configured
if [ -z "$PATRONI_ENDPOINTS" ]; then
    echo "Error: PGPOOL_PATRONI_ENDPOINTS not configured" >&2
    exit 1
fi

# Function to query a single Patroni endpoint
query_patroni() {
    local endpoint="$1"
    local response
    
    # Remove trailing slash
    endpoint="${endpoint%/}"
    
    # Query /cluster endpoint
    if response=$(curl -s --max-time "$TIMEOUT" "$endpoint/cluster" 2>/dev/null); then
        # Parse JSON to find leader
        local leader
        leader=$(echo "$response" | jq -r '.leader // empty' 2>/dev/null || echo "")
        
        if [ -n "$leader" ]; then
            # Find the leader's connection info
            local members
            members=$(echo "$response" | jq -r '.members[] | select(.name == "'"$leader"'") | .host + ":" + (.port | tostring)' 2>/dev/null || echo "")
            
            if [ -n "$members" ]; then
                echo "$members"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Try each endpoint until we find the leader
IFS=',' read -ra ENDPOINT_ARRAY <<< "$PATRONI_ENDPOINTS"
for endpoint in "${ENDPOINT_ARRAY[@]}"; do
    if primary=$(query_patroni "$endpoint"); then
        echo "$primary"
        exit 0
    fi
done

# If no leader found, exit with error
echo "Error: Could not determine primary from Patroni endpoints" >&2
exit 1
EOF
    
    # Make script executable
    chmod +x "$script_file"
    chown "$PGPOOL_USER:$PGPOOL_USER" "$script_file" 2>/dev/null || true
    
    log_info "follow_master_command script generated at: $script_file"
}

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    log_debug "Setting up signal handlers"
    
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    
    log_debug "Signal handlers configured"
}

# Main function
main() {
    log_info "PgPool-II Container Entrypoint v$SCRIPT_VERSION"
    
    # Validate environment
    validate_environment
    
    # Create necessary directories
    setup_directories
    
    # Parse backend configuration
    parse_backends
    
    # Generate follow_master_command script if Patroni is enabled
    if [ -n "${PGPOOL_PATRONI_ENDPOINTS:-}" ]; then
        generate_follow_master_command
    fi
    
    # Generate pgpool configuration
    generate_pgpool_config
    
    # Generate pool_passwd file
    generate_pool_passwd
    
    # Set up signal handlers
    setup_signal_handlers
    
    # Start pgpool-II
    start_pgpool
}

# Generate pgpool.conf configuration
generate_pgpool_config() {
    log_info "Generating pgpool.conf configuration"
    
    local config_file="$PGPOOL_CONFIG_DIR/pgpool.conf"
    
    cat > "$config_file" << EOF
# pgpool-II configuration generated by container entrypoint
# Generated on: $(date)

# Connection settings
listen_addresses = '*'
port = $PGPOOL_PORT
pcp_listen_addresses = '*'
pcp_port = $PGPOOL_PCP_PORT

# Pool settings
num_init_children = $PGPOOL_NUM_INIT_CHILDREN
max_pool = $PGPOOL_MAX_POOL
child_life_time = $PGPOOL_CHILD_LIFE_TIME
connection_life_time = $PGPOOL_CONNECTION_LIFE_TIME
child_max_connections = $PGPOOL_CHILD_MAX_CONNECTIONS

# Load balancing
load_balance_mode = $PGPOOL_LOAD_BALANCE_MODE
ignore_leading_white_space = $PGPOOL_IGNORE_LEADING_WHITE_SPACE

# Master slave mode
master_slave_mode = $PGPOOL_MASTER_SLAVE_MODE
master_slave_sub_mode = '$PGPOOL_MASTER_SLAVE_SUB_MODE'

# Add follow_master_command if Patroni is enabled
follow_master_command = '$PGPOOL_CONFIG_DIR/follow_master.sh'

# Connection pooling
connection_cache = $PGPOOL_CONNECTION_CACHE
reset_query_list = '$PGPOOL_RESET_QUERY_LIST'

# Authentication
enable_pool_hba = $PGPOOL_ENABLE_POOL_HBA
pool_passwd = '$PGPOOL_POOL_PASSWD'

# Health check
health_check_timeout = $PGPOOL_HEALTH_CHECK_TIMEOUT
health_check_period = $PGPOOL_HEALTH_CHECK_PERIOD
health_check_user = '$PGPOOL_HEALTH_CHECK_USER'
health_check_password = '$PGPOOL_HEALTH_CHECK_PASSWORD'
health_check_database = '$PGPOOL_HEALTH_CHECK_DATABASE'
health_check_max_retries = $PGPOOL_HEALTH_CHECK_MAX_RETRIES
health_check_retry_delay = $PGPOOL_HEALTH_CHECK_RETRY_DELAY

# Connection timeout
connect_timeout = $PGPOOL_CONNECT_TIMEOUT

# Streaming replication check
sr_check_period = $PGPOOL_SR_CHECK_PERIOD
sr_check_user = '$PGPOOL_SR_CHECK_USER'
sr_check_password = '$PGPOOL_SR_CHECK_PASSWORD'
sr_check_database = '$PGPOOL_SR_CHECK_DATABASE'
delay_threshold = $PGPOOL_DELAY_THRESHOLD
delay_threshold_by_time = $PGPOOL_DELAY_THRESHOLD_BY_TIME
prefer_lower_delay_standby = $PGPOOL_PREFER_LOWER_DELAY_STANDBY
log_standby_delay = '$PGPOOL_LOG_STANDBY_DELAY'

# Logging
log_destination = 'stderr'
log_line_prefix = '%t: pid %p: '
log_connections = on
log_hostname = on
log_statement = off

# Error reporting
log_error_verbosity = default
client_min_messages = notice
log_min_messages = warning

EOF

    # Add backend configurations
    for ((i=0; i<${#BACKEND_ARRAY[@]}; i++)); do
        local backend="${BACKEND_ARRAY[i]}"
        local host="${backend%:*}"
        local port="${backend#*:}"
        local weight="${WEIGHT_ARRAY[i]:-1}"
        local flag="${FLAG_ARRAY[i]:-ALLOW_TO_FAILOVER}"
        
        cat >> "$config_file" << EOF

# Backend $i
backend_hostname$i = '$host'
backend_port$i = $port
backend_weight$i = $weight
backend_data_directory$i = ''
backend_flag$i = '$flag'
backend_application_name$i = 'server$i'
EOF
    done
    
    log_info "pgpool.conf configuration generated at: $config_file"
    
    # Create pool_hba.conf if authentication is enabled
    if [ "$PGPOOL_ENABLE_POOL_HBA" = "on" ]; then
        generate_pool_hba_config
    fi
    
    # Create pool_passwd if backend password is set
    if [ -n "$PGPOOL_BACKEND_PASSWORD" ]; then
        generate_pool_passwd
    fi
}

# Handle shutdown signals
handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"
    
    # Gracefully stop pgpool-II
    if [ -f "$PGPOOL_RUN_DIR/pgpool.pid" ]; then
        log_info "Stopping pgpool-II gracefully"
        pgpool -f "$PGPOOL_CONFIG_DIR/pgpool.conf" -F "$PGPOOL_RUN_DIR/pgpool.pid" -m s stop || true
    fi
    
    log_info "Shutdown complete"
    exit 0
}

# Start pgpool-II
start_pgpool() {
    log_info "Starting pgpool-II"
    
    # Switch to pgpool user
    if [ "$(id -u)" = "0" ]; then
        log_info "Running pgpool-II as user: $PGPOOL_USER"
        exec gosu "$PGPOOL_USER" pgpool -f "$PGPOOL_CONFIG_DIR/pgpool.conf" -F "$PGPOOL_RUN_DIR/pgpool.pid" -n
    else
        log_info "Running pgpool-II as current user"
        exec pgpool -f "$PGPOOL_CONFIG_DIR/pgpool.conf" -F "$PGPOOL_RUN_DIR/pgpool.pid" -n
    fi
}

# Execute main function (moved to end after all functions are defined)
main "$@"