#!/bin/bash
# entrypoint.sh - Main container orchestrator for WordPress
# Coordinates all modular scripts for WordPress container initialization and runtime

# Set strict error handling
set -euo pipefail

# Source all utility functions first
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/wordpress.sh

# Script version
SCRIPT_VERSION="1.0.0"

# Main function
main() {
    log_script_start "entrypoint.sh v$SCRIPT_VERSION"

    # Log startup information
    log_info "WordPress Container Entrypoint v$SCRIPT_VERSION"
    log_environment

    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi

    # Validate dependencies
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi

    # Set up signal handlers
    setup_signal_handlers

    # Run initialization scripts in order
    run_initialization

    # Start runtime management
    start_runtime "$@"

    log_script_end "entrypoint.sh"
}

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    log_debug "Setting up signal handlers"

    # Handle common termination signals
    trap 'handle_shutdown SIGTERM' SIGTERM
    trap 'handle_shutdown SIGINT' SIGINT
    trap 'handle_shutdown SIGQUIT' SIGQUIT
    trap 'handle_shutdown SIGHUP' SIGHUP

    log_debug "Signal handlers configured"
}

# Handle shutdown signals
handle_shutdown() {
    local signal="$1"
    log_info "Received shutdown signal: $signal"

    # For WordPress/Apache, we don't have specific shutdown scripts
    # The main process will handle shutdown
    log_info "Shutdown complete"
    exit 0
}

# Run initialization scripts in order
run_initialization() {
    log_info "Running initialization scripts"

    local init_scripts=(
        "/opt/container/entrypoint.d/scripts/init/01-wp-config.sh"
        "/opt/container/entrypoint.d/scripts/init/02-wordpress-vars.sh"
        "/opt/container/entrypoint.d/scripts/init/03-stateless.sh"
        "/opt/container/entrypoint.d/scripts/init/04-https.sh"
        "/opt/container/entrypoint.d/scripts/init/05-table-prefix.sh"
        "/opt/container/entrypoint.d/scripts/init/06-php-limits.sh"
        "/opt/container/entrypoint.d/scripts/init/07-apache-mpm.sh"
        "/opt/container/entrypoint.d/scripts/init/08-apache-status.sh"
        "/opt/container/entrypoint.d/scripts/init/09-apache-exporter.sh"
        "/opt/container/entrypoint.d/scripts/init/10-htaccess.sh"
        "/opt/container/entrypoint.d/scripts/init/11-permissions.sh"
    )

    for script in "${init_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Running initialization script: $(basename "$script")"
            if ! "$script"; then
                log_error "Initialization script failed: $(basename "$script")"
                exit 1
            fi
        else
            log_warn "Initialization script not found or not executable: $script"
        fi
    done

    log_info "All initialization scripts completed successfully"
}

# Start runtime management
start_runtime() {
    log_info "Starting runtime management"

    local startup_script="/opt/container/entrypoint.d/scripts/runtime/startup.sh"

    if [ -f "$startup_script" ] && [ -x "$startup_script" ]; then
        log_info "Starting WordPress via startup script"
        exec "$startup_script" "$@"
    else
        log_error "Startup script not found or not executable: $startup_script"
        exit 1
    fi
}

# Execute main function
main "$@"