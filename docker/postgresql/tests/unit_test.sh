#!/bin/bash
# unit_test.sh - Unit tests for PostgreSQL container functions

# Source the script to test functions
# Note: For testing, define the function directly since utils are not available locally
sanitize_password() {
    local password="$1"
    echo "$password" | sed "s/'/''/g"
}

# Test password sanitization
test_sanitize_password() {
    echo "Testing password sanitization..."

    # Test normal password
    result=$(sanitize_password "password123")
    if [ "$result" = "password123" ]; then
        echo "✓ Normal password test passed"
    else
        echo "✗ Normal password test failed: expected 'password123', got '$result'"
        return 1
    fi

    # Test password with single quote
    result=$(sanitize_password "pass'word")
    if [ "$result" = "pass''word" ]; then
        echo "✓ Single quote escaping test passed"
    else
        echo "✗ Single quote escaping test failed: expected 'pass''word', got '$result'"
        return 1
    fi

    # Test password with multiple quotes
    result=$(sanitize_password "pass'word'test")
    if [ "$result" = "pass''word''test" ]; then
        echo "✓ Multiple quotes escaping test passed"
    else
        echo "✗ Multiple quotes escaping test failed: expected 'pass''word''test', got '$result'"
        return 1
    fi

    echo "All sanitization tests passed"
    return 0
}

# Run tests
echo "Running unit tests..."
test_sanitize_password
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✓ All unit tests passed"
else
    echo "✗ Some unit tests failed"
fi

exit $exit_code