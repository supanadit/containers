# Data Model: PostgreSQL Container Scripts

**Version**: 1.0.0
**Date**: 2025-09-22
**Status**: Design

## Overview
This document describes the modular architecture for the enhanced PostgreSQL container entrypoint system. The model defines script components, their relationships, data flow, and interaction patterns.

## Architectural Components

### Script Modules

#### 1. Utility Layer (`utils/`)
Core utility functions used across all other modules.

**logging.sh**
- **Purpose**: Structured logging and output formatting
- **Functions**:
  - `log_info()`: Info level logging
  - `log_warn()`: Warning level logging
  - `log_error()`: Error level logging with stderr output
  - `log_debug()`: Debug level logging (when DEBUG=1)
- **Dependencies**: None
- **Data Flow**: Accepts log messages, outputs formatted logs

**validation.sh**
- **Purpose**: Configuration and environment validation
- **Functions**:
  - `validate_environment()`: Check required environment variables
  - `validate_config_files()`: Verify configuration file integrity
  - `validate_permissions()`: Check file and directory permissions
  - `validate_dependencies()`: Verify required tools are available
- **Dependencies**: logging.sh
- **Data Flow**: Input: environment variables, file paths; Output: validation status (0=valid, 1=invalid)

**security.sh**
- **Purpose**: Security hardening and permission management
- **Functions**:
  - `set_secure_permissions()`: Apply secure file permissions
  - `drop_privileges()`: Switch from root to postgres user
  - `validate_security_context()`: Check current security context
  - `audit_security_event()`: Log security-related events
- **Dependencies**: logging.sh, validation.sh
- **Data Flow**: Input: file paths, user contexts; Output: security status

#### 2. Initialization Layer (`init/`)
Scripts that prepare the container environment before PostgreSQL startup.

**01-directories.sh**
- **Purpose**: Create and configure required directories
- **Functions**:
  - `create_data_directory()`: Create PGDATA with proper ownership
  - `create_config_directory()`: Create config directory structure
  - `create_backup_directory()`: Setup pgBackRest directories
  - `set_directory_permissions()`: Apply secure permissions
- **Dependencies**: utils/security.sh, utils/validation.sh
- **Data Flow**: Input: directory paths; Output: directory creation status

**02-database.sh**
- **Purpose**: Initialize PostgreSQL database cluster
- **Functions**:
  - `check_cluster_exists()`: Verify if cluster already exists
  - `initialize_cluster()`: Run initdb if needed
  - `verify_cluster_integrity()`: Check cluster health
- **Dependencies**: utils/logging.sh, utils/validation.sh
- **Data Flow**: Input: PGDATA path; Output: cluster initialization status

**03-config.sh**
- **Purpose**: Manage PostgreSQL configuration files
- **Functions**:
  - `backup_original_configs()`: Create .original backups
  - `copy_user_configs()`: Apply user-provided configurations
  - `generate_secure_defaults()`: Create secure default configs
  - `validate_config_syntax()`: Check configuration validity
- **Dependencies**: utils/validation.sh, utils/security.sh
- **Data Flow**: Input: config file paths; Output: configuration status

**04-backup.sh**
- **Purpose**: Configure pgBackRest and WAL archiving
- **Functions**:
  - `configure_pgbackrest()`: Setup pgBackRest configuration
  - `enable_archiving()`: Configure WAL archiving in postgresql.conf
  - `test_backup_connectivity()`: Verify backup system works
- **Dependencies**: utils/logging.sh, utils/validation.sh
- **Data Flow**: Input: backup configuration; Output: backup setup status

#### 3. Runtime Layer (`runtime/`)
Scripts that manage PostgreSQL process lifecycle.

**startup.sh**
- **Purpose**: Handle PostgreSQL process startup
- **Functions**:
  - `select_startup_mode()`: Choose between Patroni/direct/sleep modes
  - `start_postgresql_direct()`: Start PostgreSQL directly
  - `start_patroni()`: Start Patroni with configuration
  - `start_sleep_mode()`: Enter maintenance mode
- **Dependencies**: All utility and init modules
- **Data Flow**: Input: startup mode, process arguments; Output: process PID

**shutdown.sh**
- **Purpose**: Manage graceful PostgreSQL shutdown
- **Functions**:
  - `initiate_graceful_shutdown()`: Send SIGTERM to PostgreSQL
  - `wait_for_shutdown()`: Monitor shutdown progress (30s timeout)
  - `force_shutdown_if_needed()`: Send SIGKILL if graceful fails
  - `cleanup_resources()`: Remove PID files and temporary resources
- **Dependencies**: utils/logging.sh
- **Data Flow**: Input: process PID; Output: shutdown status

**healthcheck.sh**
- **Purpose**: Provide container health monitoring
- **Functions**:
  - `check_postgresql_connectivity()`: Test database connections
  - `check_patroni_status()`: Verify Patroni cluster health
  - `check_disk_space()`: Monitor storage availability
  - `check_process_health()`: Verify PostgreSQL process status
- **Dependencies**: utils/logging.sh
- **Data Flow**: Input: health check type; Output: health status (0=healthy, 1=unhealthy)

### Main Entrypoint (`entrypoint.sh`)
Orchestrates all modules in correct sequence.

**Execution Flow**:
1. Load utility functions
2. Validate environment and dependencies
3. Run initialization scripts in order
4. Start runtime management
5. Handle shutdown signals
6. Cleanup on exit

## Data Flow Architecture

### Initialization Phase
```
Environment Variables → validation.sh → startup.sh
                              ↓
Directory Paths → 01-directories.sh → security.sh
                              ↓
Config Files → 03-config.sh → validation.sh
                              ↓
Backup Config → 04-backup.sh → logging.sh
```

### Runtime Phase
```
Startup Mode → startup.sh → [postgresql|patroni|sleep]
                     ↓
Process PID → shutdown.sh ← Signal Handlers
                     ↓
Health Status → healthcheck.sh → Monitoring Systems
```

### Error Handling Flow
```
Any Module → logging.sh → error_exit()
       ↓
Validation → security.sh → audit_security_event()
       ↓
Recovery → cleanup_resources() → safe_shutdown()
```

## State Management

### Container States
- **UNINITIALIZED**: Initial container state
- **INITIALIZING**: Running init scripts
- **READY**: All initialization complete
- **STARTING**: PostgreSQL process starting
- **RUNNING**: PostgreSQL operational
- **STOPPING**: Graceful shutdown in progress
- **STOPPED**: Clean shutdown complete
- **ERROR**: Fatal error state

### State Transitions
```
UNINITIALIZED → INITIALIZING → READY → STARTING → RUNNING
      ↓              ↓           ↓         ↓          ↓
   ERROR         ERROR       ERROR     ERROR      STOPPING → STOPPED
                                                     ↓
                                                  ERROR
```

### State Persistence
- **PID Files**: `/usr/local/pgsql/data/postmaster.pid`
- **Lock Files**: `/tmp/postgresql-container.lock`
- **State Files**: `/tmp/container-state` (for debugging)

## Interface Contracts

### Module Interfaces
Each module exposes a consistent interface:

```bash
# Module contract
module_main() {
    # Main execution logic
    # Return 0 for success, non-zero for failure
}

# Optional: module-specific functions
module_validate() {
    # Pre-flight checks
}

module_cleanup() {
    # Cleanup on failure
}
```

### Data Contracts
- **Environment Variables**: Documented in configuration contract
- **File Paths**: Absolute paths, validated before use
- **Exit Codes**: Standardized (0=success, 1-4=error types)
- **Log Format**: Structured with timestamps and levels

## Dependencies and Coupling

### Module Dependencies
- **Utility Layer**: Independent, used by all other layers
- **Init Layer**: Depends on utilities, executed sequentially
- **Runtime Layer**: Depends on utilities and init completion
- **Entrypoint**: Depends on all modules, orchestrates execution

### Coupling Reduction
- **Interface Segregation**: Each module has single responsibility
- **Dependency Injection**: Configuration passed via environment
- **Error Isolation**: Module failures don't cascade uncontrollably
- **Testability**: Each module can be tested in isolation

## Performance Characteristics

### Execution Time Targets
- **Initialization**: < 10 seconds
- **Startup**: < 20 seconds
- **Shutdown**: < 30 seconds (graceful)
- **Health Check**: < 1 second

### Resource Usage
- **Memory**: < 50MB additional overhead
- **Disk**: < 10MB for scripts and logs
- **CPU**: Minimal additional load
- **Network**: No additional requirements

## Monitoring and Observability

### Logging Levels
- **DEBUG**: Detailed execution tracing
- **INFO**: Normal operational messages
- **WARN**: Non-critical issues
- **ERROR**: Failures requiring attention

### Metrics Collection
- **Startup Time**: Time to reach RUNNING state
- **Initialization Time**: Time for init phase completion
- **Error Count**: Number of errors encountered
- **Health Status**: Current container health

### Debugging Support
- **Verbose Mode**: Enable with `DEBUG=1`
- **Dry Run Mode**: Validate without execution (`DRY_RUN=1`)
- **State Inspection**: Query current state via healthcheck.sh