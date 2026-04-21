#!/bin/bash
# Install utility scripts to PATH

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

install_misc_scripts() {
    log_info "Installing utility scripts to PATH"
    
    local misc_scripts_dir="/opt/container/entrypoint.d/scripts/misc"
    local bin_dir="/usr/local/bin"
    
    if [ -d "$misc_scripts_dir" ]; then
        for script in "$misc_scripts_dir"/*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                local script_name
                script_name=$(basename "$script")
                local target="${bin_dir}/${script_name}"
                
                if [ ! -L "$target" ] && [ ! -f "$target" ]; then
                    ln -sf "$script" "$target"
                    log_info "Linked $script_name to $bin_dir"
                fi
            fi
        done
    fi
    
    log_info "Utility scripts installation completed"
}

install_misc_scripts
