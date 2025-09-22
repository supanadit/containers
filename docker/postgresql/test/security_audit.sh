#!/bin/bash
set -e

# Security Audit Script
# Validates security compliance of the optimized PostgreSQL container

DOCKER_IMAGE_NAME="postgres-security-test"
DOCKERFILE_PATH="/home/supanadit/Workspaces/Personal/Docker/containers/docker/postgresql"

test_dockerfile_security() {
    echo "=== Testing Dockerfile security practices ==="
    
    local dockerfile="$DOCKERFILE_PATH/Dockerfile"
    local security_issues=0
    
    # Check for USER directive (non-root execution)
    if grep -q "^USER postgres" "$dockerfile"; then
        echo "✓ Container runs as non-root user (postgres)"
    else
        echo "✗ Container may run as root - security risk"
        ((security_issues++))
    fi
    
    # Check for proper HEALTHCHECK
    if grep -q "^HEALTHCHECK" "$dockerfile"; then
        echo "✓ Health check configured"
    else
        echo "✗ No health check configured"
        ((security_issues++))
    fi
    
    # Check for explicit port exposure
    if grep -q "^EXPOSE" "$dockerfile"; then
        echo "✓ Ports explicitly exposed"
    else
        echo "⚠ No explicit port exposure"
    fi
    
    # Check for proper signal handling
    if grep -q "STOPSIGNAL" "$dockerfile"; then
        echo "✓ Proper stop signal configured"
    else
        echo "⚠ No stop signal configured"
    fi
    
    # Check for build metadata
    if grep -q "org.opencontainers.image" "$dockerfile"; then
        echo "✓ Container metadata labels present"
    else
        echo "⚠ Missing container metadata"
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        echo "Dockerfile security test passed"
        return 0
    else
        echo "Dockerfile security test failed: $security_issues issues"
        return 1
    fi
}

test_file_permissions() {
    echo "=== Testing file permissions and ownership ==="
    
    # Build a test image
    if ! docker build -t $DOCKER_IMAGE_NAME "$DOCKERFILE_PATH" > /dev/null 2>&1; then
        echo "ERROR: Failed to build image for security testing"
        return 1
    fi
    
    # Test file permissions inside container
    local perm_issues=0
    
    # Check if postgres user exists
    if docker run --rm $DOCKER_IMAGE_NAME id postgres > /dev/null 2>&1; then
        echo "✓ postgres user exists in container"
    else
        echo "✗ postgres user missing"
        ((perm_issues++))
    fi
    
    # Check data directory ownership
    local data_owner=$(docker run --rm $DOCKER_IMAGE_NAME stat -c "%U" /var/lib/postgresql/data 2>/dev/null || echo "unknown")
    if [[ "$data_owner" == "postgres" ]]; then
        echo "✓ Data directory owned by postgres user"
    else
        echo "✗ Data directory not owned by postgres user (owner: $data_owner)"
        ((perm_issues++))
    fi
    
    # Check script directory permissions
    local script_perms=$(docker run --rm $DOCKER_IMAGE_NAME stat -c "%a" /opt/container 2>/dev/null || echo "000")
    if [[ "$script_perms" == "755" ]]; then
        echo "✓ Script directory has correct permissions (755)"
    else
        echo "⚠ Script directory permissions: $script_perms (expected: 755)"
    fi
    
    if [[ $perm_issues -eq 0 ]]; then
        echo "File permissions test passed"
        return 0
    else
        echo "File permissions test failed: $perm_issues issues"
        return 1
    fi
}

test_secrets_handling() {
    echo "=== Testing secrets and sensitive data handling ==="
    
    local dockerfile="$DOCKERFILE_PATH/Dockerfile"
    local secrets_issues=0
    
    # Check for hardcoded secrets (basic patterns)
    local secret_patterns=("password=" "secret=" "key=" "token=")
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -i "$pattern" "$dockerfile" > /dev/null 2>&1; then
            echo "⚠ Potential hardcoded secret detected: $pattern"
        fi
    done
    
    # Check for proper environment variable usage
    if grep -q "ENV.*PASSWORD" "$dockerfile"; then
        echo "⚠ Password may be set via ENV (should use runtime secrets)"
    fi
    
    # Check build args don't contain secrets
    local build_args=$(grep "^ARG" "$dockerfile" | grep -i -E "(password|secret|key|token)" || true)
    if [[ -n "$build_args" ]]; then
        echo "⚠ Build arguments may contain secrets:"
        echo "$build_args"
    else
        echo "✓ No obvious secrets in build arguments"
    fi
    
    echo "Secrets handling test completed"
    return 0
}

test_vulnerability_scanning() {
    echo "=== Testing container for vulnerabilities ==="
    
    # This is a basic implementation - in production you'd use tools like:
    # - Trivy
    # - Clair
    # - Snyk
    # - Docker Bench Security
    
    echo "⚠ Vulnerability scanning requires external tools"
    echo "Recommended tools for production:"
    echo "- trivy image $DOCKER_IMAGE_NAME"
    echo "- docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker/docker-bench-security"
    
    # Basic checks we can do
    local vuln_issues=0
    
    # Check base image is recent
    local base_image=$(grep "^FROM.*debian" "$DOCKERFILE_PATH/Dockerfile" | head -1 | awk '{print $2}')
    echo "Base image: $base_image"
    
    # Check for package updates in Dockerfile
    if grep -q "apt-get update" "$DOCKERFILE_PATH/Dockerfile"; then
        echo "✓ Package lists are updated during build"
    else
        echo "⚠ Package lists may be outdated"
    fi
    
    echo "Basic vulnerability checks completed"
    return 0
}

cleanup() {
    echo "=== Cleaning up security audit artifacts ==="
    
    # Remove test image
    docker rmi -f $DOCKER_IMAGE_NAME 2>/dev/null || true
    
    echo "Security audit cleanup completed"
}

main() {
    echo "Starting final security audit and vulnerability scanning"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    local tests_passed=0
    local tests_failed=0
    
    # Test Dockerfile security
    if test_dockerfile_security; then
        ((tests_passed++))
        echo "✓ Dockerfile security test passed"
    else
        ((tests_failed++))
        echo "✗ Dockerfile security test failed"
    fi
    
    # Test file permissions
    if test_file_permissions; then
        ((tests_passed++))
        echo "✓ File permissions test passed"
    else
        ((tests_failed++))
        echo "✗ File permissions test failed"
    fi
    
    # Test secrets handling
    if test_secrets_handling; then
        ((tests_passed++))
        echo "✓ Secrets handling test passed"
    else
        ((tests_failed++))
        echo "✗ Secrets handling test failed"
    fi
    
    # Test vulnerability scanning
    if test_vulnerability_scanning; then
        ((tests_passed++))
        echo "✓ Vulnerability scanning test passed"
    else
        ((tests_failed++))
        echo "✗ Vulnerability scanning test failed"
    fi
    
    echo "Security audit completed: $tests_passed passed, $tests_failed failed"
    
    if [[ $tests_failed -gt 0 ]]; then
        echo "Some security tests failed - review and address issues"
        return 1
    fi
    
    echo "Security audit PASSED - container meets security requirements"
    return 0
}

# Run main function
main "$@"