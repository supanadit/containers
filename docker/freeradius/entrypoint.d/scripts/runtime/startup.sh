#!/bin/bash
# startup.sh - Start FreeRADIUS server

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

main() {
    log_info "Starting FreeRADIUS server"
    
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi
    
    local radiusd_bin="/usr/local/freeradius/sbin/radiusd"
    local config_dir="/usr/local/freeradius/etc/raddb"
    
    if [[ ! -x "$radiusd_bin" ]]; then
        log_error "radiusd binary not found or not executable: $radiusd_bin"
        exit 1
    fi
    
    if [[ ! -d "$config_dir" ]]; then
        log_error "Config directory not found: $config_dir"
        exit 1
    fi
    
    if [[ ! -f "$config_dir/radiusd.conf" ]]; then
        log_error "radiusd.conf not found in: $config_dir"
        exit 1
    fi
    
    local debug_flag=""
    if [[ "${RADIUS_DEBUG:-no}" == "yes" ]] || [[ "${RADIUS_DEBUG:-no}" == "true" ]]; then
        debug_flag="-x"
        log_info "Starting FreeRADIUS in debug mode"
    else
        log_info "Starting FreeRADIUS in production mode"
    fi
    
    cd "$config_dir"
    
    log_info "Starting FreeRADIUS from: $config_dir"
    log_info "Command: $radiusd_bin -f -d $config_dir"
    
    exec "$radiusd_bin" -f -d "$config_dir" 2>&1
}

main "$@"
