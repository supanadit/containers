#!/bin/bash
set -e

# Build Time Optimization Integration Test
# This test validates that build time improvements are achieved through layer caching

DOCKER_BUILDKIT=1
DOCKER_IMAGE_NAME="postgres-build-test"
DOCKERFILE_PATH="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql"

test_initial_build_time() {
    echo "=== Testing initial build time ==="
    
    # Clean up any existing images
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    # Time the initial build
    local start_time=$(date +%s)
    
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH"; then
        echo "ERROR: Initial build failed"
        return 1
    fi
    
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    
    echo "Initial build time: ${build_time}s"
    
    # Store build time for comparison
    echo "$build_time" > /tmp/initial_build_time
    
    return 0
}

test_entrypoint_change_build_time() {
    echo "=== Testing build time after entrypoint change ==="
    
    # Make a small change to an entrypoint script
    local test_script="$DOCKERFILE_PATH/entrypoint.d/scripts/runtime/startup.sh"
    local backup_file="/tmp/startup_backup.sh"
    
    # Backup original if it exists
    if [[ -f "$test_script" ]]; then
        cp "$test_script" "$backup_file"
    else
        echo "# Test startup script" > "$test_script"
        echo "echo 'Starting up...'" >> "$test_script"
    fi
    
    # Make a trivial change
    echo "# Build optimization test change $(date)" >> "$test_script"
    
    # Time the rebuild
    local start_time=$(date +%s)
    
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH"; then
        echo "ERROR: Rebuild after entrypoint change failed"
        # Restore backup
        [[ -f "$backup_file" ]] && cp "$backup_file" "$test_script"
        return 1
    fi
    
    local end_time=$(date +%s)
    local rebuild_time=$((end_time - start_time))
    
    echo "Rebuild time after entrypoint change: ${rebuild_time}s"
    
    # Restore original file
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$test_script"
        rm "$backup_file"
    else
        rm -f "$test_script"
    fi
    
    # Compare build times
    local initial_time=$(cat /tmp/initial_build_time 2>/dev/null || echo "300")
    local improvement_percent=$(( (initial_time - rebuild_time) * 100 / initial_time ))
    
    echo "Build time improvement: ${improvement_percent}%"
    
    # Test should fail if improvement is less than 50%
    if [[ $improvement_percent -lt 50 ]]; then
        echo "ERROR: Build time improvement ($improvement_percent%) is less than required 50%"
        return 1
    fi
    
    echo "Build time optimization test passed"
    return 0
}

test_cache_layer_effectiveness() {
    echo "=== Testing cache layer effectiveness ==="
    
    # Build with verbose output to see cache hits
    local build_output=$(mktemp)
    
    # Make another small change
    local test_script="$DOCKERFILE_PATH/entrypoint.d/scripts/runtime/startup.sh"
    echo "# Another test change $(date)" >> "$test_script"
    
    # Build and capture output
    docker build --progress=plain -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > "$build_output" 2>&1 || true
    
    # Count cache hits vs misses
    local cache_hits=$(grep -c "CACHED" "$build_output" || echo "0")
    local total_steps=$(grep -c "RUN\|COPY\|ADD" "$build_output" || echo "1")
    
    echo "Cache hits: $cache_hits out of $total_steps steps"
    
    local cache_rate=$(( cache_hits * 100 / total_steps ))
    echo "Cache hit rate: ${cache_rate}%"
    
    # Clean up
    rm -f "$build_output"
    
    # Test should fail if cache hit rate is less than 50%
    if [[ $cache_rate -lt 50 ]]; then
        echo "ERROR: Cache hit rate ($cache_rate%) is less than expected 50%"
        return 1
    fi
    
    echo "Cache effectiveness test passed"
    return 0
}

cleanup() {
    echo "=== Cleaning up test artifacts ==="
    
    # Remove test image
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    # Remove temporary files
    rm -f /tmp/initial_build_time
    
    echo "Cleanup completed"
}

main() {
    echo "Starting build time optimization integration tests"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    local tests_passed=0
    local tests_failed=0
    
    # Run initial build test
    if test_initial_build_time; then
        ((tests_passed++))
        echo "✓ Initial build test passed"
    else
        ((tests_failed++))
        echo "✗ Initial build test failed"
    fi
    
    # Run entrypoint change test (this should initially fail)
    if test_entrypoint_change_build_time; then
        ((tests_passed++))
        echo "✓ Entrypoint change test passed"
    else
        ((tests_failed++))
        echo "✗ Entrypoint change test failed (expected - optimization not implemented)"
    fi
    
    # Run cache effectiveness test (this should initially fail)
    if test_cache_layer_effectiveness; then
        ((tests_passed++))
        echo "✓ Cache effectiveness test passed"
    else
        ((tests_failed++))
        echo "✗ Cache effectiveness test failed (expected - optimization not implemented)"
    fi
    
    echo "Build time tests completed: $tests_passed passed, $tests_failed failed"
    
    # Return failure to drive implementation
    if [[ $tests_failed -gt 0 ]]; then
        echo "Some tests failed as expected - implementation needed"
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"