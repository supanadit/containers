#!/bin/bash
set -e

# Script Interface Contract Test
# This test validates that all setup and entrypoint scripts follow the defined interface

source "$(dirname "$0")/../../entrypoint.d/scripts/utils/logging.sh"

test_setup_script_interface() {
    log_info "Testing setup script interface compliance"
    
    # Test that setup scripts exist and are executable
    for script in /opt/setup/scripts/*.sh; do
        if [[ -f "$script" ]]; then
            log_info "Checking script: $script"
            
            # Test executable permission
            if [[ ! -x "$script" ]]; then
                log_error "Script $script is not executable"
                return 1
            fi
            
            # Test for main function (should exist)
            if ! grep -q "^main()" "$script" 2>/dev/null; then
                log_error "Script $script missing main() function"
                return 1
            fi
            
            # Test for set -e (should exist)
            if ! grep -q "set -e" "$script" 2>/dev/null; then
                log_error "Script $script missing 'set -e'"
                return 1
            fi
        fi
    done
    
    log_info "Setup script interface test passed"
    return 0
}

test_entrypoint_script_interface() {
    log_info "Testing entrypoint script interface compliance"
    
    # Test that entrypoint scripts exist and are executable
    for script in /opt/container/entrypoint.d/scripts/**/*.sh; do
        if [[ -f "$script" ]]; then
            log_info "Checking script: $script"
            
            # Test executable permission
            if [[ ! -x "$script" ]]; then
                log_error "Script $script is not executable"
                return 1
            fi
            
            # Test for main function (should exist)
            if ! grep -q "^main()" "$script" 2>/dev/null; then
                log_error "Script $script missing main() function"
                return 1
            fi
            
            # Test for utility sourcing (utils scripts should be sourced)
            if [[ "$script" != *"/utils/"* ]] && [[ "$script" != *"test"* ]]; then
                if ! grep -q "source.*logging.sh" "$script" 2>/dev/null; then
                    log_error "Script $script should source logging utilities"
                    return 1
                fi
            fi
        fi
    done
    
    log_info "Entrypoint script interface test passed"
    return 0
}

test_utility_script_interface() {
    log_info "Testing utility script interface compliance"
    
    # Test logging.sh functions
    local logging_script="/opt/container/entrypoint.d/scripts/utils/logging.sh"
    if [[ -f "$logging_script" ]]; then
        # Test required functions exist
        local required_funcs=("log_info" "log_error" "log_debug")
        for func in "${required_funcs[@]}"; do
            if ! grep -q "^$func()" "$logging_script" 2>/dev/null; then
                log_error "Missing required function: $func in logging.sh"
                return 1
            fi
        done
    else
        log_error "Utility script logging.sh not found"
        return 1
    fi
    
    log_info "Utility script interface test passed"
    return 0
}

main() {
    log_info "Starting script interface contract tests"
    
    # Run all interface tests
    test_setup_script_interface || exit 1
    test_entrypoint_script_interface || exit 1
    test_utility_script_interface || exit 1
    
    log_info "All script interface contract tests passed"
}

# Run main function
main "$@"