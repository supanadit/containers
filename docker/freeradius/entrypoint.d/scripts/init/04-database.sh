#!/bin/bash
# 04-database.sh - Initialize database schema for FreeRADIUS

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

main() {
    log_script_start "04-database.sh"
    
    if [[ "${DB_ENABLE:-false}" != "true" ]]; then
        log_debug "Database support is not enabled, skipping database initialization"
        log_script_end "04-database.sh"
        return 0
    fi
    
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-3306}"
    local db_name="${DB_NAME:-radius}"
    local db_user="${DB_USER:-root}"
    local db_pass="${DB_PASS:-}"
    local db_type="${DB_TYPE:-mysql}"
    
    log_info "Database configuration:"
    log_info "  Host: $db_host"
    log_info "  Port: $db_port"
    log_info "  Database: $db_name"
    log_info "  User: $db_user"
    log_info "  Type: $db_type"
    
    wait_for_database "$db_host" "$db_port" "$db_user" "$db_pass"
    
    create_database_if_not_exists "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass"
    
    init_schema "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "$db_type"
    
    insert_default_user "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass"
    
    log_script_end "04-database.sh"
}

wait_for_database() {
    local host="$1"
    local port="$2"
    local user="$3"
    local pass="$4"
    
    log_info "Waiting for database to be available at $host:$port"
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        set +e
        local ping_result
        local ping_error
        
        if [[ -n "$pass" ]]; then
            ping_result=$(MYSQL_PWD="$pass" mysqladmin ping -h "$host" -P "$port" -u "$user" --silent 2>&1)
            ping_error=$?
        else
            ping_result=$(mysqladmin ping -h "$host" -P "$port" -u "$user" --silent 2>&1)
            ping_error=$?
        fi
        set -e
        
        if [[ $ping_error -eq 0 ]]; then
            log_info "Database is available and responding"
            return 0
        fi
        
        log_debug "Attempt $attempt/$max_attempts: Database not ready (Error: $ping_result)..."
        sleep 2
        ((attempt++))
    done
    
    log_error "Database did not become available after $max_attempts attempts"
    return 1
}

create_database_if_not_exists() {
    local host="$1"
    local port="$2"
    local dbname="$3"
    local user="$4"
    local pass="$5"
    
    log_info "Creating database if not exists: $dbname"
    
    local sql="CREATE DATABASE IF NOT EXISTS \`$dbname\`;"
    local result
    local exit_code
    
    set +e
    if [[ -n "$pass" ]]; then
        result=$(MYSQL_PWD="$pass" mysql -h "$host" -P "$port" -u "$user" -e "$sql" 2>&1)
        exit_code=$?
    else
        result=$(mysql -h "$host" -P "$port" -u "$user" -e "$sql" 2>&1)
        exit_code=$?
    fi
    set -e
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Database '$dbname' created or already exists"
    else
        log_warn "Could not create database: $result"
    fi
}

init_schema() {
    local host="$1"
    local port="$2"
    local dbname="$3"
    local user="$4"
    local pass="$5"
    local dbtype="$6"
    
    log_info "Initializing FreeRADIUS schema"
    
    local schema_sql="
CREATE TABLE IF NOT EXISTS \`nas\` (
  \`id\` int(10) unsigned NOT NULL AUTO_INCREMENT,
  \`nasname\` varchar(128) NOT NULL,
  \`shortname\` varchar(32) NOT NULL,
  \`type\` varchar(30) DEFAULT 'other',
  \`ports\` int(5) DEFAULT NULL,
  \`secret\` varchar(60) NOT NULL DEFAULT 'secret',
  \`server\` varchar(64) DEFAULT NULL,
  \`community\` varchar(50) DEFAULT NULL,
  \`description\` varchar(200) DEFAULT NULL,
  PRIMARY KEY (\`id\`),
  KEY \`nasname\` (\`nasname\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radcheck\` (
  \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,
  \`username\` varchar(64) NOT NULL DEFAULT '',
  \`attribute\` varchar(64) NOT NULL DEFAULT '',
  \`op\` varchar(2) NOT NULL DEFAULT ':=',
  \`value\` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (\`id\`),
  KEY \`username\` (\`username\`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radreply\` (
  \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,
  \`username\` varchar(64) NOT NULL DEFAULT '',
  \`attribute\` varchar(64) NOT NULL DEFAULT '',
  \`op\` varchar(2) NOT NULL DEFAULT '=',
  \`value\` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (\`id\`),
  KEY \`username\` (\`username\`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radgroupcheck\` (
  \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,
  \`groupname\` varchar(64) NOT NULL DEFAULT '',
  \`attribute\` varchar(64) NOT NULL DEFAULT '',
  \`op\` varchar(2) NOT NULL DEFAULT ':=',
  \`value\` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (\`id\`),
  KEY \`groupname\` (\`groupname\`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radgroupreply\` (
  \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,
  \`groupname\` varchar(64) NOT NULL DEFAULT '',
  \`attribute\` varchar(64) NOT NULL DEFAULT '',
  \`op\` varchar(2) NOT NULL DEFAULT '=',
  \`value\` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (\`id\`),
  KEY \`groupname\` (\`groupname\`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radusergroup\` (
  \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,
  \`username\` varchar(64) NOT NULL DEFAULT '',
  \`groupname\` varchar(64) NOT NULL DEFAULT '',
  \`priority\` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (\`id\`),
  KEY \`username\` (\`username\`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radacct\` (
  \`radacctid\` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  \`acctsessionid\` varchar(64) NOT NULL DEFAULT '',
  \`acctuniqueid\` varchar(32) NOT NULL DEFAULT '',
  \`username\` varchar(64) NOT NULL DEFAULT '',
  \`groupname\` varchar(64) NOT NULL DEFAULT '',
  \`realm\` varchar(64) DEFAULT '',
  \`nasipaddress\` varchar(15) NOT NULL DEFAULT '',
  \`nasportid\` varchar(15) DEFAULT NULL,
  \`nasporttype\` varchar(32) DEFAULT NULL,
  \`acctstarttime\` datetime DEFAULT NULL,
  \`acctstoptime\` datetime DEFAULT NULL,
  \`acctsessiontime\` int(11) unsigned DEFAULT NULL,
  \`acctauthentic\` varchar(32) DEFAULT NULL,
  \`connectinfo_start\` varchar(50) DEFAULT NULL,
  \`connectinfo_stop\` varchar(50) DEFAULT NULL,
  \`acctinputoctets\` bigint(20) DEFAULT NULL,
  \`acctoutputoctets\` bigint(20) DEFAULT NULL,
  \`calledstationid\` varchar(50) NOT NULL DEFAULT '',
  \`callingstationid\` varchar(50) NOT NULL DEFAULT '',
  \`acctterminatecause\` varchar(32) NOT NULL DEFAULT '',
  \`servicetype\` varchar(32) DEFAULT NULL,
  \`framedprotocol\` varchar(32) DEFAULT NULL,
  \`framedipaddress\` varchar(15) NOT NULL DEFAULT '',
  PRIMARY KEY (\`radacctid\`),
  UNIQUE KEY \`acctuniqueid\` (\`acctuniqueid\`),
  KEY \`username\` (\`username\`),
  KEY \`acctsessionid\` (\`acctsessionid\`),
  KEY \`acctstarttime\` (\`acctstarttime\`),
  KEY \`acctstoptime\` (\`acctstoptime\`),
  KEY \`nasipaddress\` (\`nasipaddress\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`radpostauth\` (
  \`id\` int(11) NOT NULL AUTO_INCREMENT,
  \`username\` varchar(64) NOT NULL DEFAULT '',
  \`pass\` varchar(64) NOT NULL DEFAULT '',
  \`reply\` varchar(32) NOT NULL DEFAULT '',
  \`authdate\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (\`id\`),
  KEY \`username\` (\`username\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"
    
    local result
    local exit_code
    
    set +e
    if [[ -n "$pass" ]]; then
        result=$(echo "$schema_sql" | MYSQL_PWD="$pass" mysql -h "$host" -P "$port" -u "$user" "$dbname" 2>&1)
        exit_code=$?
    else
        result=$(echo "$schema_sql" | mysql -h "$host" -P "$port" -u "$user" "$dbname" 2>&1)
        exit_code=$?
    fi
    set -e
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Schema initialized successfully"
    else
        log_error "Failed to initialize schema: $result"
        return 1
    fi
    
    log_info "Schema initialization completed"
}

insert_default_user() {
    local host="$1"
    local port="$2"
    local dbname="$3"
    local user="$4"
    local pass="$5"
    
    local user_name="${FREERADIUS_USER_NAME:-admin}"
    local user_password="${FREERADIUS_USER_PASSWORD:-admin}"
    
    log_info "Checking for default user in database"
    
    local check_sql="SELECT COUNT(*) as count FROM radcheck WHERE username='$user_name' AND attribute='Cleartext-Password'"
    
    local user_exists=0
    local check_result
    
    set +e
    if [[ -n "$pass" ]]; then
        check_result=$(MYSQL_PWD="$pass" mysql -h "$host" -P "$port" -u "$user" "$dbname" -e "$check_sql" 2>&1)
    else
        check_result=$(mysql -h "$host" -P "$port" -u "$user" "$dbname" -e "$check_sql" 2>&1)
    fi
    set -e
    
    if echo "$check_result" | grep -q "[1-9]"; then
        user_exists=1
    fi
    
    if [[ $user_exists -eq 0 ]]; then
        log_info "Inserting default user '$user_name' into database"
        
        local insert_sql="INSERT INTO radcheck (username, attribute, op, value) VALUES ('$user_name', 'Cleartext-Password', ':=', '$user_password')"
        
        local insert_result
        local exit_code
        
        set +e
        if [[ -n "$pass" ]]; then
            insert_result=$(MYSQL_PWD="$pass" mysql -h "$host" -P "$port" -u "$user" "$dbname" -e "$insert_sql" 2>&1)
            exit_code=$?
        else
            insert_result=$(mysql -h "$host" -P "$port" -u "$user" "$dbname" -e "$insert_sql" 2>&1)
            exit_code=$?
        fi
        set -e
        
        if [[ $exit_code -eq 0 ]]; then
            log_info "Default user created successfully"
        else
            log_error "Could not insert default user: $insert_result"
            return 1
        fi
    else
        log_debug "User '$user_name' already exists in database"
    fi
}

main "$@"
