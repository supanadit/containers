#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "daloRADIUS Container Entrypoint"
echo "=========================================="

# Source utility functions
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh

# Main function
main() {
    log_info "Starting daloRADIUS initialization"
    
    # Log environment
    log_environment
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    # Run initialization scripts in order
    run_initialization
    
    # Start runtime
    start_runtime "$@"
}

# Run initialization scripts in order
run_initialization() {
    log_info "Running initialization scripts"
    
    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/01-config-gen.sh"
        "/opt/container/entrypoint.d/scripts/init/02-db-check.sh"
        "/opt/container/entrypoint.d/scripts/init/03-permissions.sh"
    )
    
    for script in "${init_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Running: $(basename "$script")"
            if ! "$script"; then
                log_error "Initialization script failed: $(basename "$script")"
                exit 1
            fi
        else
            log_warn "Initialization script not found or not executable: $script"
        fi
    done
    
    log_info "All initialization scripts completed"
}

# Start runtime
start_runtime() {
    log_info "Starting Apache HTTP Server"
    
    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"
    
    if [ -f "$startup_script" ] && [ -x "$startup_script" ]; then
        exec "$startup_script" "$@"
    else
        log_error "Startup script not found: $startup_script"
        exit 1
    fi
}

main "$@"
