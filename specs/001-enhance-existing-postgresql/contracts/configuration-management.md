# Contract: Configuration Management

**Contract ID**: CONFIG-001
**Version**: 1.0.0
**Date**: 2025-09-22
**Status**: Active

## Overview
This contract defines how configuration files are managed, validated, and applied in the PostgreSQL container. It ensures consistent handling of postgresql.conf, pg_hba.conf, and Patroni configuration.

## Configuration Sources

### Primary Sources
1. **Container Environment**: Environment variables override defaults
2. **Config Directory**: `/usr/local/pgsql/config/` - user-provided configurations
3. **Data Directory**: `/usr/local/pgsql/data/` - generated defaults
4. **Templates**: Built-in secure defaults

### Configuration Hierarchy
```
Environment Variables (highest priority)
    ↓
User Config Files (/usr/local/pgsql/config/)
    ↓
Generated Defaults (/usr/local/pgsql/data/)
    ↓
Secure Templates (lowest priority)
```

## File Management Contract

### File Permissions
- **Configuration Files**: `0644` (readable by all, writable by owner)
- **Data Directories**: `0755` (readable/executable by all, writable by owner)
- **Sensitive Files**: `0600` (readable/writable by owner only)
- **Executable Scripts**: `0755` (readable/executable by all, writable by owner)

### Backup Strategy
- Original files saved with `.original` extension
- Backups created before any modification
- Backup integrity verification
- Automatic cleanup of old backups

### Atomic Operations
- Configuration changes applied atomically
- Rollback capability on failure
- Temporary files used for safe updates
- Validation before committing changes

## Configuration File Specifications

### postgresql.conf
**Location**: `/usr/local/pgsql/data/postgresql.conf`
**Owner**: postgres:postgres
**Permissions**: 0644

**Required Settings**:
```ini
# Archive configuration (when enabled)
archive_mode = on
archive_command = 'pgbackrest --stanza=default archive-push %p'

# Security settings
listen_addresses = '*'
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_statement = 'ddl'
log_duration = on

# Performance tuning
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
```

### pg_hba.conf
**Location**: `/usr/local/pgsql/data/pg_hba.conf`
**Owner**: postgres:postgres
**Permissions**: 0644

**Default Entries**:
```ini
# Local connections
local   all             postgres                                peer
local   all             all                                     md5

# Docker container connections
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
```

### Patroni Configuration
**Location**: `/etc/patroni.yml`
**Owner**: postgres:postgres
**Permissions**: 0644

**Required Structure**:
```yaml
scope: postgres-cluster
name: postgres-node-1
restapi:
  listen: 0.0.0.0:8008
  connect_address: localhost:8008
etcd:
  host: localhost:2379
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        logging_collector: "on"
        max_wal_senders: 10
        max_replications_slots: 10
        wal_keep_segments: 8
        archive_mode: "on"
        archive_timeout: 1800s
        archive_command: "pgbackrest --stanza=default archive-push %p"
postgresql:
  listen: 0.0.0.0:5432
  connect_address: localhost:5432
  data_dir: /usr/local/pgsql/data
  config_dir: /usr/local/pgsql/data
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: replicator_password
    superuser:
      username: postgres
      password: postgres_password
  parameters:
    unix_socket_directories: '/tmp'
```

## Validation Contract

### Configuration Validation
- Syntax validation for all config files
- Semantic validation of parameter values
- Cross-reference validation between files
- Security policy compliance checking

### Validation Functions
```bash
validate_postgresql_conf() {
    # Check required parameters
    # Validate value ranges
    # Check for conflicts
}

validate_pg_hba_conf() {
    # Check connection rules
    # Validate IP addresses/networks
    # Check authentication methods
}

validate_patroni_config() {
    # Check YAML syntax
    # Validate required fields
    # Check connectivity to DCS
}
```

### Error Handling
- Clear error messages for validation failures
- Suggestions for fixing configuration issues
- Non-blocking warnings for optional settings

## Environment Variable Mapping

### PostgreSQL Settings
- `POSTGRESQL_SHARED_BUFFERS` → `shared_buffers`
- `POSTGRESQL_MAX_CONNECTIONS` → `max_connections`
- `POSTGRESQL_WORK_MEM` → `work_mem`
- `POSTGRESQL_MAINTENANCE_WORK_MEM` → `maintenance_work_mem`

### Security Settings
- `POSTGRESQL_LISTEN_ADDRESSES` → `listen_addresses`
- `POSTGRESQL_LOG_STATEMENT` → `log_statement`
- `POSTGRESQL_LOG_DURATION` → `log_duration`

### Archive Settings
- `PGBACKREST_STANZA` → stanza name in archive_command
- `ARCHIVE_TIMEOUT` → `archive_timeout`

## Migration Contract

### Backward Compatibility
- Existing environment variables preserved
- Old configuration formats supported
- Graceful degradation for missing settings

### Version Negotiation
- Configuration version detection
- Automatic migration of old formats
- Deprecation warnings for obsolete settings

## Security Considerations

### Sensitive Data Handling
- Passwords never logged in plain text
- Configuration files with appropriate permissions
- Secure temporary file creation
- Input sanitization for all parameters

### Access Control
- Configuration files readable by postgres user
- No world-writable files
- Secure directory permissions
- Audit logging of configuration changes