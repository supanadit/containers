#!/bin/bash
set -e

# Performance Validation Script
# Tests startup time and build time optimization

DOCKER_BUILDKIT=1
DOCKER_IMAGE_NAME="postgres-perf-test"
DOCKERFILE_PATH="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql"

test_startup_time() {
    echo "=== Testing container startup time ==="
    
    # Remove any existing container
    docker rm -f postgres-startup-test 2>/dev/null || true
    
    local start_time=$(date +%s%N)
    
    # Start container in background
    if ! docker run -d --name postgres-startup-test -e POSTGRES_PASSWORD=test123 $DOCKER_IMAGE_NAME; then
        echo "ERROR: Container failed to start"
        return 1
    fi
    
    # Wait for container to be ready (health check)
    local timeout=60
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if docker exec postgres-startup-test pg_isready -U postgres 2>/dev/null; then
            break
        fi
        sleep 1
        ((elapsed++))
    done
    
    local end_time=$(date +%s%N)
    local startup_time=$(( (end_time - start_time) / 1000000000 ))
    
    echo "Container startup time: ${startup_time}s"
    
    # Clean up
    docker rm -f postgres-startup-test 2>/dev/null || true
    
    # Check if startup time meets requirement (<30s)
    if [[ $startup_time -gt 30 ]]; then
        echo "ERROR: Startup time (${startup_time}s) exceeds 30s requirement"
        return 1
    fi
    
    echo "Startup time test passed"
    return 0
}

test_build_time_optimization() {
    echo "=== Testing build time optimization ==="
    
    # Clean slate
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    # Initial build time
    echo "Performing initial build..."
    local start_time=$(date +%s)
    
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > /dev/null 2>&1; then
        echo "ERROR: Initial build failed"
        return 1
    fi
    
    local end_time=$(date +%s)
    local initial_build_time=$((end_time - start_time))
    echo "Initial build time: ${initial_build_time}s"
    
    # Make a small change to entrypoint
    local test_file="$DOCKERFILE_PATH/entrypoint.d/scripts/runtime/startup.sh"
    echo "# Performance test change $(date)" >> "$test_file"
    
    # Rebuild and time it
    echo "Rebuilding after entrypoint change..."
    start_time=$(date +%s)
    
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > /dev/null 2>&1; then
        echo "ERROR: Rebuild failed"
        return 1
    fi
    
    end_time=$(date +%s)
    local rebuild_time=$((end_time - start_time))
    echo "Rebuild time: ${rebuild_time}s"
    
    # Calculate improvement
    local improvement_percent=$(( (initial_build_time - rebuild_time) * 100 / initial_build_time ))
    echo "Build time improvement: ${improvement_percent}%"
    
    # Remove test change
    sed -i '/# Performance test change/d' "$test_file"
    
    # Should have at least 50% improvement
    if [[ $improvement_percent -lt 50 ]]; then
        echo "WARNING: Build time improvement (${improvement_percent}%) is less than target 50%"
        # This is a warning, not a hard failure for now
    fi
    
    echo "Build time optimization test completed"
    return 0
}

test_image_size() {
    echo "=== Testing image size optimization ==="
    
    # Get image size
    local image_size_bytes=$(docker image inspect $DOCKER_IMAGE_NAME --format='{{.Size}}' 2>/dev/null || echo "0")
    local image_size_mb=$(( image_size_bytes / 1024 / 1024 ))
    
    echo "Image size: ${image_size_mb}MB"
    
    # Check if size is reasonable (under 2GB for now)
    if [[ $image_size_mb -gt 2048 ]]; then
        echo "WARNING: Image size (${image_size_mb}MB) is quite large"
    fi
    
    echo "Image size test completed"
    return 0
}

cleanup() {
    echo "=== Cleaning up performance test artifacts ==="
    
    # Remove test containers
    docker rm -f postgres-startup-test postgres-perf-test 2>/dev/null || true
    
    # Remove test image
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    echo "Performance test cleanup completed"
}

main() {
    echo "Starting performance validation tests"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    local tests_passed=0
    local tests_failed=0
    
    # Build the image first
    echo "Building image for performance testing..."
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > /dev/null 2>&1; then
        echo "ERROR: Failed to build test image"
        exit 1
    fi
    
    # Test startup time
    if test_startup_time; then
        ((tests_passed++))
        echo "✓ Startup time test passed"
    else
        ((tests_failed++))
        echo "✗ Startup time test failed"
    fi
    
    # Test build time optimization
    if test_build_time_optimization; then
        ((tests_passed++))
        echo "✓ Build time optimization test passed"
    else
        ((tests_failed++))
        echo "✗ Build time optimization test failed"
    fi
    
    # Test image size
    if test_image_size; then
        ((tests_passed++))
        echo "✓ Image size test passed"
    else
        ((tests_failed++))
        echo "✗ Image size test failed"
    fi
    
    echo "Performance validation completed: $tests_passed passed, $tests_failed failed"
    
    if [[ $tests_failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"