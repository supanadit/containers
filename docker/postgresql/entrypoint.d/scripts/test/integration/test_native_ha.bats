#!/usr/bin/env bats
# test_native_ha.bats - Integration tests for native HA validation logic

# Setup test environment
setup() {
    # Create a temporary directory for test isolation
    TEST_DIR="$(mktemp -d)"
    
    # Get the workspace root directory (relative to this test file)
    # Since bats is run from workspace root, use relative paths from there
    WORKSPACE_ROOT="$(pwd)"
    
    # Copy validation.sh to test directory and modify source path
    cp "$WORKSPACE_ROOT/docker/postgresql/entrypoint.d/scripts/utils/validation.sh" "$TEST_DIR/"
    cp "$WORKSPACE_ROOT/docker/postgresql/entrypoint.d/scripts/utils/logging.sh" "$TEST_DIR/"
    
    # Modify validation.sh to source logging.sh from test directory
    sed -i 's|source /opt/container/entrypoint.d/scripts/utils/logging.sh|source '"$TEST_DIR"'/logging.sh|' "$TEST_DIR/validation.sh"
    
    # Source the modified validation.sh
    source "$TEST_DIR/validation.sh"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

@test "Native HA: Fails when HA_MODE=native and USE_PATRONI=true" {
    export HA_MODE="native"
    export USE_PATRONI="true"
    
    run bash -c "validate_ha_configuration" 2>&1
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"HA_MODE=native cannot be used with USE_PATRONI=true"* ]]
}

@test "Native HA: Fails when HA_MODE=native and USE_CITUS=true" {
    export HA_MODE="native"
    export USE_CITUS="true"
    
    run bash -c "validate_ha_configuration" 2>&1
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"HA_MODE=native cannot be used with USE_CITUS=true"* ]]
}

@test "Native HA: Fails with invalid REPLICATION_ROLE" {
    export HA_MODE="native"
    export REPLICATION_ROLE="invalid"
    
    run bash -c "validate_ha_configuration" 2>&1
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid REPLICATION_ROLE"* ]]
}

@test "Native HA: Fails when replica is missing PRIMARY_HOST" {
    export HA_MODE="native"
    export REPLICATION_ROLE="replica"
    unset PRIMARY_HOST
    
    run bash -c "validate_ha_configuration" 2>&1
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"PRIMARY_HOST must be set for replica role"* ]]
}

@test "Native HA: Validation passes with valid primary config" {
    export HA_MODE="native"
    export REPLICATION_ROLE="primary"
    
    run bash -c "validate_ha_configuration" 2>&1
    
    [ "$status" -eq 0 ]
}
