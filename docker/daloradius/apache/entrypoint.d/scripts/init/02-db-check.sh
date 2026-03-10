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
    set +e
    if [ -n "$DALORADIUS_DB_PASS" ]; then
        ping_result=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysqladmin ping -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" --silent 2>&1)
        ping_error=$?
    else
        ping_result=$(mysqladmin ping -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" --silent 2>&1)
        ping_error=$?
    fi
    set -e
    
    if [ $ping_error -eq 0 ]; then
        log_info "Database is reachable"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_debug "Attempt $RETRY_COUNT/$MAX_RETRIES - Database not ready yet (Error: $ping_result)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_warn "Could not connect to database after $MAX_RETRIES attempts"
    log_warn "The application may not function correctly until the database is available"
    log_warn "Please ensure your MySQL/MariaDB server is running and accessible"
fi

# Ensure database exists
log_info "Ensuring database '$DALORADIUS_DB_NAME' exists"
set +e
if [ -n "$DALORADIUS_DB_PASS" ]; then
    db_result=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" -e "CREATE DATABASE IF NOT EXISTS \`$DALORADIUS_DB_NAME\`;" 2>&1)
else
    db_result=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" -e "CREATE DATABASE IF NOT EXISTS \`$DALORADIUS_DB_NAME\`;" 2>&1)
fi
set -e
log_info "Database ready"

# Check for required tables
log_info "Checking for required database tables"

# Try to check for operators table (daloRADIUS specific)
set +e
if [ -n "$DALORADIUS_DB_PASS" ]; then
    TABLE_CHECK=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" -e "SHOW TABLES LIKE 'operators';" 2>&1)
else
    TABLE_CHECK=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" -e "SHOW TABLES LIKE 'operators';" 2>&1)
fi
set -e

if ! echo "$TABLE_CHECK" | grep -q "operators"; then
    log_warn "daloRADIUS tables not found, attempting automatic migration..."
    
    # Define SQL schema files (master branch uses MariaDB variants)
    FREERADIUS_SCHEMA="/var/www/html/daloradius/contrib/db/fr3-mariadb-freeradius.sql"
    DALORADIUS_SCHEMA="/var/www/html/daloradius/contrib/db/mariadb-daloradius.sql"
    
    # Check if schema files exist, try alternative names if not found
    if [ ! -f "$FREERADIUS_SCHEMA" ]; then
        # Try alternative filenames
        if [ -f "/var/www/html/daloradius/contrib/db/fr3-mysql-freeradius.sql" ]; then
            FREERADIUS_SCHEMA="/var/www/html/daloradius/contrib/db/fr3-mysql-freeradius.sql"
        elif [ -f "/var/www/html/daloradius/contrib/db/fr2-mysql-freeradius.sql" ]; then
            FREERADIUS_SCHEMA="/var/www/html/daloradius/contrib/db/fr2-mysql-freeradius.sql"
        else
            log_error "FreeRADIUS schema file not found in contrib/db/"
            ls -la /var/www/html/daloradius/contrib/db/ 2>&1 || true
            exit 1
        fi
    fi
    
    if [ ! -f "$DALORADIUS_SCHEMA" ]; then
        # Try alternative filenames
        if [ -f "/var/www/html/daloradius/contrib/db/mysql-daloradius.sql" ]; then
            DALORADIUS_SCHEMA="/var/www/html/daloradius/contrib/db/mysql-daloradius.sql"
        else
            log_error "daloRADIUS schema file not found in contrib/db/"
            ls -la /var/www/html/daloradius/contrib/db/ 2>&1 || true
            exit 1
        fi
    fi
    
    log_info "Using FreeRADIUS schema: $FREERADIUS_SCHEMA"
    log_info "Using daloRADIUS schema: $DALORADIUS_SCHEMA"
    
    # Import FreeRADIUS schema
    log_info "Importing FreeRADIUS schema..."
    set +e
    if [ -n "$DALORADIUS_DB_PASS" ]; then
        import_result=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" < "$FREERADIUS_SCHEMA" 2>&1)
        import_error=$?
    else
        import_result=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" < "$FREERADIUS_SCHEMA" 2>&1)
        import_error=$?
    fi
    set -e
    
    if [ $import_error -ne 0 ]; then
        log_warn "FreeRADIUS schema import warning: $import_result"
    else
        log_info "FreeRADIUS schema imported successfully"
    fi
    
    # Import daloRADIUS schema
    log_info "Importing daloRADIUS schema..."
    set +e
    if [ -n "$DALORADIUS_DB_PASS" ]; then
        import_result=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" < "$DALORADIUS_SCHEMA" 2>&1)
        import_error=$?
    else
        import_result=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" < "$DALORADIUS_SCHEMA" 2>&1)
        import_error=$?
    fi
    set -e
    
    if [ $import_error -ne 0 ]; then
        log_warn "daloRADIUS schema import warning: $import_result"
    else
        log_info "daloRADIUS schema imported successfully"
    fi
    
    # Verify tables now exist
    log_info "Verifying database tables..."
    set +e
    if [ -n "$DALORADIUS_DB_PASS" ]; then
        TABLE_CHECK=$(MYSQL_PWD="$DALORADIUS_DB_PASS" mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" -e "SHOW TABLES LIKE 'operators';" 2>&1)
    else
        TABLE_CHECK=$(mysql -h "$DALORADIUS_DB_HOST" -P "$DALORADIUS_DB_PORT" -u "$DALORADIUS_DB_USER" "$DALORADIUS_DB_NAME" -e "SHOW TABLES LIKE 'operators';" 2>&1)
    fi
    set -e
    
    if ! echo "$TABLE_CHECK" | grep -q "operators"; then
        log_error "Failed to initialize daloRADIUS tables automatically"
        exit 1
    fi
    
    log_info "daloRADIUS tables initialized successfully"
fi

log_info "Database tables verified successfully"
