# Contract: Script Interface

## Overview
This contract defines the interface that all setup and entrypoint scripts must adhere to for consistent execution and caching optimization.

## Setup Scripts Contract (setup/scripts/*.sh)

### Function Signatures
```bash
#!/bin/bash
set -e

# Required: Main execution function
main() {
    # Script implementation
}

# Optional: Logging functions (use provided utilities)
log_info "Starting setup script"
log_error "Setup failed"

# Required: Call main function
main "$@"
```

### Requirements
- Must be executable and idempotent
- Must use provided logging utilities from utils/
- Must handle errors gracefully with set -e
- Must not depend on entrypoint scripts
- Must clean up temporary files

### Outputs
- Installed packages and binaries
- Configuration files in appropriate directories
- No runtime dependencies on entrypoint layer

## Entrypoint Scripts Contract (entrypoint.d/scripts/*.sh)

### Function Signatures
```bash
#!/bin/bash
set -e

# Required: Main execution function
main() {
    # Script implementation
}

# Required: Use utility functions
source /opt/container/scripts/utils/logging.sh
source /opt/container/scripts/utils/validation.sh

# Optional: Health check function
health_check() {
    # Return 0 for healthy, 1 for unhealthy
}

# Required: Call main function
main "$@"
```

### Requirements
- Must assume setup layer is complete
- Must use absolute paths for all references
- Must implement proper signal handling
- Must provide health check endpoints if applicable
- Must follow structured logging format

### Dependencies
- Setup layer must be present
- Utility scripts must be available
- Configuration files must be staged

## Utility Scripts Contract (entrypoint.d/scripts/utils/*.sh)

### Required Functions
```bash
# logging.sh
log_info() { ... }
log_error() { ... }
log_debug() { ... }

# validation.sh
validate_config() { ... }
validate_environment() { ... }

# security.sh
secure_setup() { ... }
validate_permissions() { ... }
```

### Requirements
- Must be pure functions with no side effects
- Must be sourced by other scripts
- Must handle errors without exiting
- Must be compatible with set -e

## Testing Contract
All scripts must be testable independently:
- Setup scripts: Test installation outcomes
- Entrypoint scripts: Test runtime behavior
- Utility scripts: Test function outputs

## Version Compatibility
- Scripts must be backward compatible
- Breaking changes require version updates
- Deprecation warnings for old interfaces