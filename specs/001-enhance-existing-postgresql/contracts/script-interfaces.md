# Contract: Script Interfaces

**Contract ID**: SCRIPT-001
**Version**: 1.0.0
**Date**: 2025-09-22
**Status**: Active

## Overview
This contract defines the interfaces and behaviors for all modular scripts in the PostgreSQL container enhancement. It ensures consistent parameter handling, error reporting, and exit codes across all scripts.

## Script Categories

### Initialization Scripts (`init/`)
Located in `/opt/container/init/` within the container.

#### Interface Standard
```bash
#!/bin/bash
# Script header with description and parameters

# Parameter validation
validate_parameters() {
    # Return 0 for success, 1 for failure
}

# Main logic
main() {
    # Return 0 for success, non-zero for failure
}

# Error handling
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Execute main function
main "$@"
```

#### Required Parameters
- All scripts accept no parameters (configuration via environment variables only)
- Scripts must be idempotent (safe to run multiple times)

#### Exit Codes
- `0`: Success
- `1`: General error
- `2`: Configuration error
- `3`: Permission error
- `4`: Dependency missing

#### Logging
- Use structured logging: `echo "INFO: message"`
- Error messages to stderr: `echo "ERROR: message" >&2`
- Warning messages: `echo "WARN: message" >&2`

### Runtime Scripts (`runtime/`)
Located in `/opt/container/runtime/` within the container.

#### Interface Standard
```bash
#!/bin/bash
# Runtime script for process management

# Parameter validation (if parameters accepted)
validate_parameters() {
    # Return 0 for success, 1 for failure
}

# Process management functions
start_process() {
    # Start background process, return PID
}

stop_process() {
    # Stop process gracefully, return exit code
}

# Signal handling
cleanup() {
    stop_process
    exit 0
}

# Main execution
main() {
    trap cleanup SIGTERM SIGINT
    start_process
    wait $PID
}

main "$@"
```

#### Parameters
- May accept command-line arguments for process configuration
- Environment variables for runtime configuration

#### Process Management
- Must handle SIGTERM for graceful shutdown
- Must implement 30-second shutdown timeout
- Must clean up PID files and resources

### Utility Scripts (`utils/`)
Located in `/opt/container/utils/` within the container.

#### Interface Standard
```bash
#!/bin/bash
# Utility functions library

# Function definitions only
# No main execution
# Source this file to use functions

validate_config() {
    # Return 0 for valid, 1 for invalid
}

log_message() {
    # Structured logging function
}

check_permissions() {
    # Permission validation
}
```

#### Usage
- Sourced by other scripts: `source /opt/container/utils/logging.sh`
- Provide reusable functions
- No standalone execution

## Environment Variables

### Global Configuration
- `PGDATA`: PostgreSQL data directory (default: `/usr/local/pgsql/data`)
- `PGCONFIG`: Configuration directory (default: `/usr/local/pgsql/config`)
- `LOG_LEVEL`: Logging verbosity (DEBUG, INFO, WARN, ERROR)
- `TIMEOUT`: Default timeout in seconds (default: 30)

### Mode Selection
- `USE_PATRONI`: Enable Patroni mode (true/false)
- `SLEEP_MODE`: Enable maintenance mode (true/false)
- `BACKUP_ENABLED`: Enable pgBackRest (true/false)

### Security
- `RUN_AS_ROOT`: Allow root operations (false by default)
- `STRICT_PERMISSIONS`: Enforce strict file permissions (true by default)

## Error Handling Contract

### Error Propagation
- Scripts must not suppress errors silently
- Errors must be logged with context
- Exit codes must follow the defined standard
- Calling scripts must check return codes

### Recovery Strategies
- Scripts should attempt cleanup on failure
- Partial initialization should be revertible
- Error messages should include recovery suggestions

## Testing Contract

### Unit Testing
- Each script must have corresponding test file
- Tests must cover success and failure paths
- Mock external dependencies where possible

### Integration Testing
- End-to-end container testing
- Configuration validation
- Performance benchmarking

## Version Compatibility
- Scripts must maintain backward compatibility
- Interface changes require version negotiation
- Deprecation warnings for obsolete interfaces

## Implementation Notes
- All scripts must be POSIX compliant
- Use `set -e` for strict error handling
- Document all assumptions and dependencies
- Include usage examples in comments