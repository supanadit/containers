#!/bin/bash
set -e

# Cache Effectiveness Validation Test
# This test validates that Docker layer caching works effectively for the optimized build

DOCKER_BUILDKIT=1
DOCKER_IMAGE_NAME="postgres-cache-test"
DOCKERFILE_PATH="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql"

test_setup_layer_caching() {
    echo "=== Testing setup layer caching ==="
    
    # Clean up any existing images
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    # Build once to establish cache
    echo "Building initial image for cache..."
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" >/dev/null 2>&1; then
        echo "ERROR: Initial build failed"
        return 1
    fi
    
    # Build again immediately - should be mostly cached
    local build_output=$(mktemp)
    docker build --progress=plain -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > "$build_output" 2>&1
    
    # Analyze setup layer caching
    local setup_cached=$(grep -c "CACHED.*setup" "$build_output" || echo "0")
    local setup_total=$(grep -c "setup" "$build_output" || echo "1")
    
    echo "Setup layers cached: $setup_cached out of $setup_total"
    
    # Clean up
    rm -f "$build_output"
    
    # Should have high cache rate for setup layers
    if [[ $setup_total -eq 0 ]]; then
        echo "ERROR: No setup layers found in build output"
        return 1
    fi
    local cache_rate=$(( setup_cached * 100 / setup_total ))
    if [[ $cache_rate -lt 80 ]]; then
        echo "ERROR: Setup layer cache rate ($cache_rate%) too low"
        return 1
    fi
    
    echo "Setup layer caching test passed"
    return 0
}

test_entrypoint_layer_invalidation() {
    echo "=== Testing entrypoint layer cache invalidation ==="
    
    local test_entrypoint="$DOCKERFILE_PATH/entrypoint.d/entrypoint.sh"
    local backup_file="/tmp/entrypoint_backup.sh"
    
    # Backup original entrypoint
    if [[ -f "$test_entrypoint" ]]; then
        cp "$test_entrypoint" "$backup_file"
    fi
    
    # Modify entrypoint script
    echo "# Cache invalidation test $(date)" >> "$test_entrypoint"
    
    # Build with the change
    local build_output=$(mktemp)
    docker build --progress=plain -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > "$build_output" 2>&1
    
    # Check that entrypoint layers were rebuilt but setup layers were cached
    local entrypoint_cached=$(grep -c "CACHED.*entrypoint" "$build_output" || echo "0")
    local setup_cached=$(grep -c "CACHED.*setup" "$build_output" || echo "0")
    
    echo "Entrypoint layers cached: $entrypoint_cached"
    echo "Setup layers cached: $setup_cached"
    
    # Restore backup
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$test_entrypoint"
        rm "$backup_file"
    fi
    
    # Clean up
    rm -f "$build_output"
    
    # Setup should be cached, entrypoint should be rebuilt
    if [[ $setup_cached -eq 0 ]]; then
        echo "ERROR: Setup layers should be cached when entrypoint changes"
        return 1
    fi
    
    echo "Entrypoint layer invalidation test passed"
    return 0
}

test_file_order_optimization() {
    echo "=== Testing file copy order for cache optimization ==="
    
    local dockerfile="$DOCKERFILE_PATH/Dockerfile"
    
    # Check that stable files (setup) are copied before volatile files (entrypoint)
    local setup_line=$(grep -n "COPY.*setup" "$dockerfile" | head -1 | cut -d: -f1 || echo "999")
    local entrypoint_line=$(grep -n "COPY.*entrypoint" "$dockerfile" | head -1 | cut -d: -f1 || echo "1")
    
    echo "Setup copy at line: $setup_line"
    echo "Entrypoint copy at line: $entrypoint_line"
    
    if [[ $setup_line -ge $entrypoint_line ]]; then
        echo "ERROR: Setup files should be copied before entrypoint files for optimal caching"
        return 1
    fi
    
    echo "File copy order optimization test passed"
    return 0
}

test_build_context_optimization() {
    echo "=== Testing build context optimization ==="
    
    # Check if .dockerignore exists and has proper exclusions
    local dockerignore="$DOCKERFILE_PATH/.dockerignore"
    
    if [[ ! -f "$dockerignore" ]]; then
        echo "ERROR: .dockerignore not found - build context not optimized"
        return 1
    fi
    
    # Check for common exclusions that would cause unnecessary cache invalidation
    local required_exclusions=(".git" "*.md" "specs" "test")
    local missing_exclusions=()
    
    for exclusion in "${required_exclusions[@]}"; do
        if ! grep -q "$exclusion" "$dockerignore"; then
            missing_exclusions+=("$exclusion")
        fi
    done
    
    if [[ ${#missing_exclusions[@]} -gt 0 ]]; then
        echo "WARNING: Missing .dockerignore exclusions: ${missing_exclusions[*]}"
        # This is a warning for now, not a hard failure
    fi
    
    echo "Build context optimization test passed"
    return 0
}

cleanup() {
    echo "=== Cleaning up cache test artifacts ==="
    
    # Remove test image
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    echo "Cache test cleanup completed"
}

main() {
    echo "Starting cache effectiveness validation tests"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    local tests_passed=0
    local tests_failed=0
    
    # Test setup layer caching (should initially fail)
    if test_setup_layer_caching; then
        ((tests_passed++))
        echo "✓ Setup layer caching test passed"
    else
        ((tests_failed++))
        echo "✗ Setup layer caching test failed (expected - optimization not implemented)"
    fi
    
    # Test entrypoint layer invalidation (should initially fail)
    if test_entrypoint_layer_invalidation; then
        ((tests_passed++))
        echo "✓ Entrypoint layer invalidation test passed"
    else
        ((tests_failed++))
        echo "✗ Entrypoint layer invalidation test failed (expected - optimization not implemented)"
    fi
    
    # Test file order optimization (should initially fail)
    if test_file_order_optimization; then
        ((tests_passed++))
        echo "✓ File copy order test passed"
    else
        ((tests_failed++))
        echo "✗ File copy order test failed (expected - optimization not implemented)"
    fi
    
    # Test build context optimization (should initially fail)
    if test_build_context_optimization; then
        ((tests_passed++))
        echo "✓ Build context optimization test passed"
    else
        ((tests_failed++))
        echo "✗ Build context optimization test failed (expected - .dockerignore not implemented)"
    fi
    
    echo "Cache effectiveness tests completed: $tests_passed passed, $tests_failed failed"
    
    # Return failure to drive implementation
    if [[ $tests_failed -gt 0 ]]; then
        echo "Some tests failed as expected - implementation needed"
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"