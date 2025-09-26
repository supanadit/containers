# Container Configuration: postgresql

## Environment Variables

### Core PostgreSQL Configuration
- **POSTGRES_PASSWORD**: Database superuser password (string, optional)
  - Default: none
  - Used: Database initialization and password modification
  - Security: Sanitized, not logged in plain text

- **TIMEOUT_CHANGE_PASSWORD**: Timeout for password modification operation (integer, seconds)
  - Default: 5
  - Range: 1-300
  - Used: Prevents hangs during password setting

### Existing Configuration Variables
- **PGDATA**: PostgreSQL data directory
  - Default: /var/lib/postgresql/data
- **POSTGRES_USER**: Database superuser username
  - Default: postgres
- **POSTGRES_DB**: Default database name
  - Default: postgres
- **PGPORT**: PostgreSQL port
  - Default: 5432

### Patroni Configuration (if applicable)
- **PATRONI_NAME**: Patroni cluster member name
- **PATRONI_NAMESPACE**: Kubernetes namespace
- **PATRONI_SCOPE**: Patroni cluster scope

## Volume Mount Points

### Data Persistence
- **/var/lib/postgresql/data**: PostgreSQL data directory
  - Type: Named volume or bind mount
  - Purpose: Persistent database storage
  - Permissions: Owned by postgres user

### Configuration Volumes (optional)
- **/etc/postgresql/custom.conf.d**: Custom PostgreSQL configuration
  - Type: ConfigMap or bind mount
  - Purpose: Additional configuration files
  - Format: PostgreSQL configuration syntax

### Backup Volumes (optional)
- **/var/lib/pgbackrest**: pgBackRest backup storage
  - Type: Persistent volume
  - Purpose: Database backups
  - Permissions: Owned by postgres user

## Port Exposure and Network Requirements

### Primary Ports
- **5432/tcp**: PostgreSQL client connections
  - Protocol: TCP
  - Purpose: Database access
  - Binding: Container port, host binding optional

### Patroni Ports (if HA enabled)
- **8008/tcp**: Patroni REST API
  - Protocol: TCP
  - Purpose: Cluster management
  - Binding: Internal cluster communication

## Configuration File Templates

### postgresql.conf
Location: /etc/postgresql/postgresql.conf
Purpose: Main PostgreSQL configuration
Template: Generated during initialization

### pg_hba.conf
Location: /etc/postgresql/pg_hba.conf
Purpose: Client authentication configuration
Template: Allows local and password authentication

### patroni.yml (if applicable)
Location: /etc/patroni/patroni.yml
Purpose: Patroni high availability configuration
Template: Generated from environment variables

## Secrets Management

### Environment Variables for Secrets
- All sensitive data passed via environment variables
- No file-based secrets in container
- Container does not persist secrets

### Password Handling
- POSTGRES_PASSWORD processed securely
- Sanitization of invalid input
- No logging of password values
- Secure SQL execution

## Configuration Validation

### Startup Validation
- Check POSTGRES_PASSWORD format if provided
- Validate TIMEOUT_CHANGE_PASSWORD range
- Verify volume mount accessibility
- Test PostgreSQL configuration syntax

### Runtime Validation
- Health check verifies database connectivity
- Monitor configuration file changes
- Validate Patroni cluster status (if applicable)

## Default Configuration Strategy

### Initialization Order
1. Environment variable processing
2. Configuration file generation
3. Database initialization
4. Password modification (if POSTGRES_PASSWORD set)
5. Service startup

### Fallback Behavior
- Missing POSTGRES_PASSWORD: Continue without password modification
- Invalid TIMEOUT_CHANGE_PASSWORD: Use default 5 seconds
- Volume mount issues: Fail with clear error message