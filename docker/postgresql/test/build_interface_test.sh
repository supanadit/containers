#!/bin/bash
set -e

# Build Interface Contract Test
# This test validates that the Dockerfile follows the build optimization interface

test_dockerfile_structure() {
    echo "=== Testing Dockerfile structure for build optimization ==="
    
    local dockerfile="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql/Dockerfile"
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "ERROR: Dockerfile not found at $dockerfile"
        return 1
    fi
    
    # Test for multi-stage build capability (should have FROM statements)
    if ! grep -q "^FROM" "$dockerfile"; then
        echo "ERROR: No FROM statement found in Dockerfile"
        return 1
    fi
    
    # Test for layer ordering - stable files should come before volatile files
    local stable_found=false
    local volatile_found=false
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Check for stable file copies (setup scripts)
        if [[ "$line" =~ COPY.*setup ]]; then
            stable_found=true
            stable_line=$line_num
        fi
        
        # Check for volatile file copies (entrypoint scripts)  
        if [[ "$line" =~ COPY.*entrypoint ]]; then
            volatile_found=true
            volatile_line=$line_num
            
            # If both found, stable should come before volatile
            if [[ "$stable_found" == true ]] && [[ $stable_line -gt $volatile_line ]]; then
                echo "ERROR: Stable files (setup) should be copied before volatile files (entrypoint)"
                echo "Stable line: $stable_line, Volatile line: $volatile_line"
                return 1
            fi
        fi
    done < "$dockerfile"
    
    echo "Dockerfile structure test passed"
    return 0
}

test_dockerignore_exists() {
    echo "=== Testing .dockerignore for build context optimization ==="
    
    local dockerignore="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql/.dockerignore"
    
    if [[ ! -f "$dockerignore" ]]; then
        echo "WARNING: .dockerignore not found - build context not optimized"
        # This is a warning, not a failure yet
        return 0
    fi
    
    # Test for common exclusions
    local required_exclusions=(".git" "*.md" "specs")
    for exclusion in "${required_exclusions[@]}"; do
        if ! grep -q "$exclusion" "$dockerignore"; then
            echo "WARNING: .dockerignore missing exclusion: $exclusion"
        fi
    done
    
    echo ".dockerignore test passed"
    return 0
}

test_build_args_defined() {
    echo "=== Testing build arguments for versioning ==="
    
    local dockerfile="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql/Dockerfile"
    
    # Test for version arguments
    local required_args=("POSTGRESQL_VERSION" "PATRONI_VERSION")
    for arg in "${required_args[@]}"; do
        if ! grep -q "ARG $arg" "$dockerfile"; then
            echo "ERROR: Missing required ARG: $arg"
            return 1
        fi
    done
    
    echo "Build arguments test passed"
    return 0
}

test_non_root_user() {
    echo "=== Testing non-root user configuration ==="
    
    local dockerfile="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql/Dockerfile"
    
    # This test will initially fail as we haven't implemented non-root yet
    if ! grep -q "USER" "$dockerfile"; then
        echo "ERROR: No USER directive found - container runs as root"
        return 1
    fi
    
    echo "Non-root user test passed"
    return 0
}

test_health_check_defined() {
    echo "=== Testing health check configuration ==="
    
    local dockerfile="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql/Dockerfile"
    
    # This test will initially fail as we haven't implemented health check yet
    if ! grep -q "HEALTHCHECK" "$dockerfile"; then
        echo "ERROR: No HEALTHCHECK directive found"
        return 1
    fi
    
    echo "Health check test passed"
    return 0
}

main() {
    echo "Starting build interface contract tests"
    local tests_passed=0
    local tests_failed=0
    
    # Run structure test (should pass)
    if test_dockerfile_structure; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Run dockerignore test (warning only)
    if test_dockerignore_exists; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Run build args test (should pass)
    if test_build_args_defined; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Run non-root test (should fail initially)
    if test_non_root_user; then
        ((tests_passed++))
    else
        ((tests_failed++))
        echo "Expected failure: Non-root user not implemented yet"
    fi
    
    # Run health check test (should fail initially)
    if test_health_check_defined; then
        ((tests_passed++))
    else
        ((tests_failed++))
        echo "Expected failure: Health check not implemented yet"
    fi
    
    echo "Build interface tests completed: $tests_passed passed, $tests_failed failed"
    
    # Return failure to indicate tests need implementation
    if [[ $tests_failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Run main function
main "$@"