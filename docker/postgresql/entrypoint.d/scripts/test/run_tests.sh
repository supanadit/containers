#!/bin/bash
# run_tests.sh - Test execution script for PostgreSQL container
# Runs all tests using BATS framework

# Set strict error handling
set -euo pipefail

# Source logging utilities if available
if [ -f "/opt/container/entrypoint.d/scripts/utils/logging.sh" ]; then
    source /opt/container/entrypoint.d/scripts/utils/logging.sh
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
fi

# Test configuration
TEST_DIR="/opt/container/entrypoint.d/scripts/test"
BATS_CMD="bats"
TEST_TIMEOUT=300

# Main function
main() {
    log_info "Starting test execution"

    # Check if BATS is available
    if ! command -v "$BATS_CMD" >/dev/null 2>&1; then
        log_error "BATS testing framework not found. Please install BATS first."
        log_error "Run: apt-get update && apt-get install -y bats"
        exit 1
    fi

    # Check if test directory exists
    if [ ! -d "$TEST_DIR" ]; then
        log_error "Test directory not found: $TEST_DIR"
        exit 1
    fi

    # Run all test suites
    local exit_code=0

    run_unit_tests || exit_code=1
    run_integration_tests || exit_code=1
    run_performance_tests || exit_code=1

    # Generate test report
    generate_test_report

    if [ $exit_code -eq 0 ]; then
        log_info "All tests passed successfully"
    else
        log_error "Some tests failed"
    fi

    return $exit_code
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests"

    local unit_test_dir="$TEST_DIR/unit"
    if [ ! -d "$unit_test_dir" ]; then
        log_warn "Unit test directory not found: $unit_test_dir"
        return 0
    fi

    local test_files
    test_files=$(find "$unit_test_dir" -name "*.bats" -type f)

    if [ -z "$test_files" ]; then
        log_warn "No unit test files found"
        return 0
    fi

    log_info "Found unit test files: $(echo "$test_files" | wc -l)"

    # Run unit tests with timeout
    if timeout "$TEST_TIMEOUT" $BATS_CMD $test_files; then
        log_info "Unit tests passed"
        return 0
    else
        log_error "Unit tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests"

    local integration_test_dir="$TEST_DIR/integration"
    if [ ! -d "$integration_test_dir" ]; then
        log_warn "Integration test directory not found: $integration_test_dir"
        return 0
    fi

    local test_files
    test_files=$(find "$integration_test_dir" -name "*.bats" -type f)

    if [ -z "$test_files" ]; then
        log_warn "No integration test files found"
        return 0
    fi

    log_info "Found integration test files: $(echo "$test_files" | wc -l)"

    # Set test environment variables
    export TEST_MODE=true
    export LOG_LEVEL=DEBUG

    # Run integration tests with timeout
    if timeout "$TEST_TIMEOUT" $BATS_CMD $test_files; then
        log_info "Integration tests passed"
        return 0
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# Run performance tests
run_performance_tests() {
    log_info "Running performance tests"

    local performance_test_dir="$TEST_DIR/performance"
    if [ ! -d "$performance_test_dir" ]; then
        log_warn "Performance test directory not found: $performance_test_dir"
        return 0
    fi

    local test_files
    test_files=$(find "$performance_test_dir" -name "*.bats" -type f)

    if [ -z "$test_files" ]; then
        log_warn "No performance test files found"
        return 0
    fi

    log_info "Found performance test files: $(echo "$test_files" | wc -l)"

    # Run performance tests with timeout
    if timeout "$TEST_TIMEOUT" $BATS_CMD $test_files; then
        log_info "Performance tests passed"
        return 0
    else
        log_error "Performance tests failed"
        return 1
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report"

    local report_file="/tmp/test_report.txt"
    local start_time
    start_time=$(date +%s)

    {
        echo "PostgreSQL Container Test Report"
        echo "Generated: $(date)"
        echo "================================="
        echo ""
        echo "Test Environment:"
        echo "  Container: $(hostname)"
        echo "  User: $(whoami)"
        echo "  BATS Version: $($BATS_CMD --version 2>/dev/null || echo 'unknown')"
        echo ""
        echo "Test Results:"
        echo "  Unit Tests: $(find "$TEST_DIR/unit" -name "*.bats" 2>/dev/null | wc -l) files"
        echo "  Integration Tests: $(find "$TEST_DIR/integration" -name "*.bats" 2>/dev/null | wc -l) files"
        echo "  Performance Tests: $(find "$TEST_DIR/performance" -name "*.bats" 2>/dev/null | wc -l) files"
        echo ""
        echo "Total Test Files: $(find "$TEST_DIR" -name "*.bats" 2>/dev/null | wc -l)"
        echo ""
        echo "Execution Time: $(( $(date +%s) - start_time )) seconds"
    } > "$report_file"

    log_info "Test report saved to: $report_file"
}

# Execute main function
main "$@"