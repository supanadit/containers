#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Checking database connectivity"

# Set defaults
DALORADIUS_DB_HOST="${DALORADIUS_DB_HOST:-mysql}"
DALORADIUS_DB_USER="${DALORADIUS_DB_USER:-radius}"
DALORADIUS_DB_PASS="${DALORADIUS_DB_PASS:-radius}"
DALORADIUS_DB_NAME="${DALORADIUS_DB_NAME:-radius}"
DALORADIUS_DB_PORT="${DALORADIUS_DB_PORT:-3306}"

# Check for MySQL client
if ! command -v mysql &> /dev/null; then
    log_warn "MySQL client not found, skipping database connectivity check"
    log_warn "Please ensure your database is properly configured"
    exit 0
fi

# Wait for database to be available
MAX_RETRIES=30
RETRY_COUNT=0

log_info "Waiting for database at ${DALORADIUS_DB_HOST}:${DALORADIUS_DB_PORT}"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysqladmin ping -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" -p"$DALORADIUS_DB_PASS" --silent 2>/dev/null; then
        log_info "Database is reachable"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_debug "Attempt $RETRY_COUNT/$MAX_RETRIES - Database not ready yet"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_warn "Could not connect to database after $MAX_RETRIES attempts"
    log_warn "The application may not function correctly until the database is available"
    log_warn "Please ensure your MySQL/MariaDB server is running and accessible"
fi

# Check for required tables
log_info "Checking for required database tables"

# Try to check for operators table (daloRADIUS specific)
TABLE_CHECK=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" -p"$DALORADIUS_DB_PASS" "$DALORADIUS_DB_NAME" -e "SHOW TABLES LIKE 'operators';" 2>/dev/null || echo "")

if [ -z "$TABLE_CHECK" ]; then
    log_error "=========================================="
    log_error "WARNING: daloRADIUS tables not found!"
    log_error "=========================================="
    log_error ""
    log_error "The database '$DALORADIUS_DB_NAME' does not contain the required daloRADIUS tables."
    log_error ""
    log_error "Please initialize your database with the following steps:"
    log_error ""
    log_error "1. Connect to your MySQL/MariaDB server"
    log_error "2. Create the database: CREATE DATABASE $DALORADIUS_DB_NAME;"
    log_error "3. Import the SQL schemas:"
    log_error "   mysql -u root -p $DALORADIUS_DB_NAME < /var/www/html/daloradius/contrib/db/fr3-mysql-freeradius.sql"
    log_error "   mysql -u root -p $DALORADIUS_DB_NAME < /var/www/html/daloradius/contrib/db/mysql-daloradius.sql"
    log_error ""
    log_error "SQL schema files are located in:"
    log_error "  /var/www/html/daloradius/contrib/db/"
    log_error ""
    log_error "Default login credentials after setup:"
    log_error "  Username: administrator"
    log_error "  Password: radius"
    log_error "=========================================="
    
    # Exit with error if tables are missing
    exit 1
fi

log_info "Database tables verified successfully"
