#!/bin/bash
set -euo pipefail

# MariaDB Entrypoint Script
# Initializes and starts MariaDB server

# Add MariaDB to PATH
export PATH="/usr/local/mariadb/bin:/usr/local/mariadb/scripts:$PATH"

# Default data directory
MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"

# Environment variables for database setup
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
MARIADB_DATABASE="${MARIADB_DATABASE:-}"
MARIADB_USER="${MARIADB_USER:-}"
MARIADB_PASSWORD="${MARIADB_PASSWORD:-}"
MARIADB_ALLOW_EMPTY_PASSWORD="${MARIADB_ALLOW_EMPTY_PASSWORD:-no}"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

# Function to initialize database if data directory is empty
initialize_database() {
    if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
        log "Initializing MariaDB data directory at $MARIADB_DATA_DIR"
        
        # Create data directory if it doesn't exist
        mkdir -p "$MARIADB_DATA_DIR"
        chown -R mysql:mysql "$MARIADB_DATA_DIR"
        
        # Initialize the database
        mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR" --rpm
        
        log "Database initialized successfully"
    else
        log "Database already initialized, skipping initialization"
    fi
}

# Function to setup initial database configuration
setup_database() {
    log "Setting up initial database configuration"
    
    # Create temporary SQL file for initial setup
    local init_sql="/tmp/init.sql"
    
    # Start SQL commands
    cat > "$init_sql" << EOF
-- Set root password if provided
EOF
    
    if [ -n "$MARIADB_ROOT_PASSWORD" ]; then
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';" >> "$init_sql"
    elif [ "$MARIADB_ALLOW_EMPTY_PASSWORD" != "yes" ]; then
        log "Warning: No root password set and empty passwords not allowed"
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '';" >> "$init_sql"
    fi
    
    # Create database if specified
    if [ -n "$MARIADB_DATABASE" ]; then
        echo "CREATE DATABASE IF NOT EXISTS \`$MARIADB_DATABASE\`;" >> "$init_sql"
    fi
    
    # Create user if specified
    if [ -n "$MARIADB_USER" ] && [ -n "$MARIADB_PASSWORD" ]; then
        echo "CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD';" >> "$init_sql"
        if [ -n "$MARIADB_DATABASE" ]; then
            echo "GRANT ALL PRIVILEGES ON \`$MARIADB_DATABASE\`.* TO '$MARIADB_USER'@'%';" >> "$init_sql"
        fi
    fi
    
    echo "FLUSH PRIVILEGES;" >> "$init_sql"
    
    # Run the initialization SQL
    mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --skip-networking --socket=/tmp/mysql.sock &
    local pid=$!
    
    # Wait for MariaDB to start
    sleep 5
    
    # Execute initialization SQL
    mariadb --socket=/tmp/mysql.sock -u root < "$init_sql"
    
    # Stop the temporary instance
    kill $pid
    wait $pid 2>/dev/null || true
    
    # Clean up
    rm -f "$init_sql" /tmp/mysql.sock
    
    log "Initial database setup completed"
}

# Function to start MariaDB
start_mariadb() {
    log "Starting MariaDB server"
    
    # Set ownership
    chown -R mysql:mysql "$MARIADB_DATA_DIR"
    
    # Start MariaDB
    exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --console
}

# Main execution
main() {
    log "MariaDB container entrypoint starting"
    
    if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
        # Initialize database if needed
        initialize_database
        
        # Setup initial configuration
        setup_database
    else
        log "Database already initialized, skipping setup"
    fi
    
    # Start MariaDB
    start_mariadb
}

# Run main function
main "$@"