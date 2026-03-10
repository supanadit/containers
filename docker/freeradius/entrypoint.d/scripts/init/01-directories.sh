#!/bin/bash
# 01-directories.sh - Create directories and set permissions

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

main() {
    log_script_start "01-directories.sh"
    
    local radius_base="/usr/local/freeradius"
    local radius_etc="$radius_base/etc/raddb"
    local radius_log="$radius_base/log"
    local radius_run="$radius_base/run"
    local radius_var="$radius_base/var"
    
    local directories=(
        "$radius_base"
        "$radius_etc"
        "$radius_log"
        "$radius_run"
        "$radius_var"
        "$radius_var/log"
        "$radius_var/run"
        "$radius_etc/certs"
        "$radius_etc/sites-available"
        "$radius_etc/sites-enabled"
        "$radius_etc/mods-available"
        "$radius_etc/mods-enabled"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        else
            log_debug "Directory already exists: $dir"
        fi
    done
    
    if id "freerad" &>/dev/null; then
        for dir in "${directories[@]}"; do
            chown -R freerad:freerad "$dir" 2>/dev/null || true
        done
        log_debug "Set ownership to freerad:freerad"
    fi
    
    chmod 755 "$radius_etc" 2>/dev/null || true
    chmod 777 "$radius_log" 2>/dev/null || true
    chmod 777 "$radius_run" 2>/dev/null || true
    
    mkdir -p "$radius_log/radacct"
    chmod 777 "$radius_log/radacct" 2>/dev/null || true
    
    log_script_end "01-directories.sh"
}

main "$@"
