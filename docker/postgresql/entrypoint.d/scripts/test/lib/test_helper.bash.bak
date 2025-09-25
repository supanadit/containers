# Test helper for BATS tests
# Provides common test utilities

# Simple assertion helpers
assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Expected success, got status $status"
        return 1
    fi
}

assert_failure() {
    if [ "$status" -eq 0 ]; then
        echo "Expected failure, got success"
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain '$expected', got: $output"
        return 1
    fi
}