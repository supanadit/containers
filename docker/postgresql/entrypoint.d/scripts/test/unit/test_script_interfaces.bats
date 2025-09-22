#!/usr/bin/env bats
# Contract test for script interfaces
# Tests the interface contracts defined in contracts/script-interfaces.md

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export LOG_LEVEL=DEBUG
}

teardown() {
    # Clean up after each test
    unset TEST_MODE
}

# Test utility script interface contract
@test "utility scripts follow interface contract" {
    # Test logging.sh interface
    run source /opt/container/entrypoint.d/scripts/utils/logging.sh
    [ "$status" -eq 0 ]

    # Test that required functions are available
    run type log_info
    [ "$status" -eq 0 ]

    run type log_warn
    [ "$status" -eq 0 ]

    run type log_error
    [ "$status" -eq 0 ]

    run type log_debug
    [ "$status" -eq 0 ]
}

@test "validation.sh provides required functions" {
    run source /opt/container/entrypoint.d/scripts/utils/validation.sh
    [ "$status" -eq 0 ]

    # Test required validation functions
    run type validate_environment
    [ "$status" -eq 0 ]

    run type validate_config_files
    [ "$status" -eq 0 ]

    run type validate_permissions
    [ "$status" -eq 0 ]

    run type validate_dependencies
    [ "$status" -eq 0 ]
}

@test "security.sh provides required functions" {
    run source /opt/container/entrypoint.d/scripts/utils/security.sh
    [ "$status" -eq 0 ]

    # Test required security functions
    run type set_secure_permissions
    [ "$status" -eq 0 ]

    run type drop_privileges
    [ "$status" -eq 0 ]

    run type validate_security_context
    [ "$status" -eq 0 ]

    run type audit_security_event
    [ "$status" -eq 0 ]
}

# Test initialization script interface contract
@test "init scripts follow interface contract" {
    # Test 01-directories.sh interface
    run /opt/container/entrypoint.d/scripts/init/01-directories.sh
    [ "$status" -eq 0 ]

    # Test 02-database.sh interface
    run /opt/container/entrypoint.d/scripts/init/02-database.sh
    [ "$status" -eq 0 ]

    # Test 03-config.sh interface
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Test 04-backup.sh interface
    run /opt/container/entrypoint.d/scripts/init/04-backup.sh
    [ "$status" -eq 0 ]
}

# Test runtime script interface contract
@test "runtime scripts follow interface contract" {
    # Test startup.sh interface
    run /opt/container/entrypoint.d/scripts/runtime/startup.sh
    [ "$status" -eq 0 ]

    # Test shutdown.sh interface
    run /opt/container/entrypoint.d/scripts/runtime/shutdown.sh
    [ "$status" -eq 0 ]

    # Test healthcheck.sh interface
    run /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh
    [ "$status" -eq 0 ]
}

# Test exit code contract
@test "scripts follow exit code contract" {
    # Test that scripts return appropriate exit codes
    # This will fail until scripts are implemented
    run /opt/container/entrypoint.d/scripts/utils/logging.sh
    [ "$status" -eq 0 ]

    run /opt/container/entrypoint.d/scripts/init/01-directories.sh
    [ "$status" -eq 0 ]
}

# Test environment variable contract
@test "scripts handle environment variables correctly" {
    # Test LOG_LEVEL handling
    export LOG_LEVEL=DEBUG
    run source /opt/container/entrypoint.d/scripts/utils/logging.sh && log_debug "test"
    [ "$status" -eq 0 ]

    # Test PGDATA handling
    export PGDATA="/tmp/test_pgdata"
    run source /opt/container/entrypoint.d/scripts/utils/validation.sh && validate_environment
    [ "$status" -eq 0 ]
}

# Test error handling contract
@test "scripts follow error handling contract" {
    # Test that errors are logged appropriately
    run source /opt/container/entrypoint.d/scripts/utils/logging.sh && log_error "test error"
    [ "$status" -eq 0 ]

    # Test that validation failures are handled
    export INVALID_CONFIG=true
    run source /opt/container/entrypoint.d/scripts/utils/validation.sh && validate_config_files
    [ "$status" -ne 0 ]  # Should fail with invalid config
}