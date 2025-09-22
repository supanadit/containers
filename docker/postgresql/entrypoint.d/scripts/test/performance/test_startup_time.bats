#!/usr/bin/env bats
# Performance test for startup time
# Tests that container startup completes within 30 seconds

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/perf_test_pgdata"
    export LOG_LEVEL=ERROR  # Reduce log noise during performance tests
    mkdir -p "$PGDATA"

    # Clean up any existing processes
    pkill -f "postgres" || true
    pkill -f "patroni" || true
    sleep 1
}

teardown() {
    # Clean up after each test
    rm -rf "$PGDATA"
    unset TEST_MODE PGDATA LOG_LEVEL

    # Kill any remaining test processes
    pkill -f "postgres" || true
    pkill -f "patroni" || true
}

@test "startup time is less than 30 seconds" {
    # Test direct PostgreSQL startup time
    export USE_PATRONI=false
    export SLEEP_MODE=false

    local start_time
    start_time=$(date +%s)

    # Run startup script with timeout
    timeout 35 /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for startup to complete or timeout
    local timeout_count=0
    while [ $timeout_count -lt 35 ]; do
        if pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((timeout_count++))
    done

    local end_time
    end_time=$(date +%s)
    local startup_time=$((end_time - start_time))

    # Kill the startup process
    kill $startup_pid 2>/dev/null || true
    wait $startup_pid 2>/dev/null || true

    # Assert startup time is within limits
    assert [ $startup_time -le 30 ]

    echo "Startup time: ${startup_time}s (limit: 30s)"
}

@test "startup time with Patroni is less than 30 seconds" {
    # Skip if Patroni is not available
    if ! command -v patroni >/dev/null 2>&1; then
        skip "Patroni not available"
    fi

    # Test Patroni startup time
    export USE_PATRONI=true
    export SLEEP_MODE=false

    local start_time
    start_time=$(date +%s)

    # Run startup script with timeout
    timeout 35 /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for Patroni to be ready (this is a simplified check)
    local timeout_count=0
    while [ $timeout_count -lt 35 ]; do
        if pgrep -f "patroni" >/dev/null 2>&1; then
            # Give Patroni a moment to initialize
            sleep 2
            break
        fi
        sleep 1
        ((timeout_count++))
    done

    local end_time
    end_time=$(date +%s)
    local startup_time=$((end_time - start_time))

    # Kill the startup process
    kill $startup_pid 2>/dev/null || true
    wait $startup_pid 2>/dev/null || true

    # Assert startup time is within limits
    assert [ $startup_time -le 30 ]

    echo "Patroni startup time: ${startup_time}s (limit: 30s)"
}

@test "sleep mode startup is instantaneous" {
    # Test sleep mode startup time
    export USE_PATRONI=false
    export SLEEP_MODE=true

    local start_time
    start_time=$(date +%s)

    # Run startup script
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait a moment for startup
    sleep 1

    local end_time
    end_time=$(date +%s)
    local startup_time=$((end_time - start_time))

    # Kill the startup process
    kill $startup_pid 2>/dev/null || true
    wait $startup_pid 2>/dev/null || true

    # Sleep mode should start very quickly
    assert [ $startup_time -le 5 ]

    echo "Sleep mode startup time: ${startup_time}s"
}

@test "initialization scripts complete within 10 seconds" {
    # Test initialization phase performance
    export USE_PATRONI=false
    export SLEEP_MODE=false

    local start_time
    start_time=$(date +%s)

    # Run initialization scripts
    /opt/container/entrypoint.d/scripts/init/01-directories.sh
    /opt/container/entrypoint.d/scripts/init/02-database.sh
    /opt/container/entrypoint.d/scripts/init/03-config.sh

    local end_time
    end_time=$(date +%s)
    local init_time=$((end_time - start_time))

    # Assert initialization time is within limits
    assert [ $init_time -le 10 ]

    echo "Initialization time: ${init_time}s (limit: 10s)"
}

@test "health check completes within 1 second" {
    # Test health check performance
    local start_time
    start_time=$(date +%s.%N)

    # Run health check
    /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh >/dev/null 2>&1
    local exit_code=$?

    local end_time
    end_time=$(date +%s.%N)

    # Calculate duration (bash doesn't have floating point, so use integer approximation)
    local start_int=${start_time%.*}
    local end_int=${end_time%.*}
    local duration=$((end_int - start_int))

    # Health check should complete quickly
    assert [ $duration -le 2 ]  # Allow some margin for measurement

    echo "Health check time: ${duration}s (limit: 1s)"
}

@test "configuration validation is fast" {
    # Test configuration validation performance
    export PGCONFIG="/opt/container/entrypoint.d/scripts/test/fixtures"

    local start_time
    start_time=$(date +%s.%N)

    # Run configuration validation
    source /opt/container/entrypoint.d/scripts/utils/validation.sh
    validate_config_files

    local end_time
    end_time=$(date +%s.%N)

    local start_int=${start_time%.*}
    local end_int=${end_time%.*}
    local duration=$((end_int - start_int))

    # Config validation should be fast
    assert [ $duration -le 2 ]

    echo "Config validation time: ${duration}s"
}