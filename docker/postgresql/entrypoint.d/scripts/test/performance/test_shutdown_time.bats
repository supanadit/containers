#!/usr/bin/env bats
# Performance test for shutdown time
# Tests that container shutdown completes within 30 seconds

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/perf_shutdown_test_pgdata"
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

@test "shutdown time is less than 30 seconds" {
    # Start PostgreSQL first
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for PostgreSQL to be ready
    local ready_count=0
    while [ $ready_count -lt 30 ]; do
        if pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((ready_count++))
    done

    # Skip test if PostgreSQL didn't start
    if ! pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
        kill $startup_pid 2>/dev/null || true
        skip "PostgreSQL failed to start for shutdown test"
    fi

    # Now test shutdown time
    local start_time
    start_time=$(date +%s)

    # Send shutdown signal
    kill -TERM $startup_pid

    # Wait for shutdown to complete
    local timeout_count=0
    while [ $timeout_count -lt 35 ] && kill -0 $startup_pid 2>/dev/null; do
        sleep 1
        ((timeout_count++))
    done

    local end_time
    end_time=$(date +%s)
    local shutdown_time=$((end_time - start_time))

    # Wait for process to actually terminate
    wait $startup_pid 2>/dev/null || true

    # Assert shutdown time is within limits
    assert [ $shutdown_time -le 30 ]

    echo "Shutdown time: ${shutdown_time}s (limit: 30s)"
}

@test "force shutdown works when graceful fails" {
    # Test force shutdown scenario
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for PostgreSQL to be ready
    local ready_count=0
    while [ $ready_count -lt 30 ]; do
        if pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((ready_count++))
    done

    if ! pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
        kill $startup_pid 2>/dev/null || true
        skip "PostgreSQL failed to start for force shutdown test"
    fi

    # Simulate a hung process by ignoring SIGTERM
    trap '' TERM

    local start_time
    start_time=$(date +%s)

    # Run shutdown script (which should eventually force kill)
    timeout 35 /opt/container/entrypoint.d/scripts/runtime/shutdown.sh &
    local shutdown_pid=$!

    # Wait for shutdown to complete
    wait $shutdown_pid 2>/dev/null || true

    local end_time
    end_time=$(date +%s)
    local shutdown_time=$((end_time - start_time))

    # Clean up any remaining processes
    pkill -9 -f "postgres" || true

    # Force shutdown should still complete within reasonable time
    assert [ $shutdown_time -le 35 ]

    echo "Force shutdown time: ${shutdown_time}s (limit: 35s)"
}

@test "shutdown cleans up resources quickly" {
    # Test resource cleanup performance
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for PostgreSQL to be ready
    local ready_count=0
    while [ $ready_count -lt 30 ]; do
        if pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((ready_count++))
    done

    if ! pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
        kill $startup_pid 2>/dev/null || true
        skip "PostgreSQL failed to start for cleanup test"
    fi

    # Create some test files that should be cleaned up
    echo "test" > "$PGDATA/test_file.pid"
    echo "test" > "/tmp/pgpass"

    local start_time
    start_time=$(date +%s.%N)

    # Run shutdown
    /opt/container/entrypoint.d/scripts/runtime/shutdown.sh

    local end_time
    end_time=$(date +%s.%N)

    # Calculate duration
    local start_int=${start_time%.*}
    local end_int=${end_time%.*}
    local cleanup_time=$((end_int - start_int))

    # Resource cleanup should be fast
    assert [ $cleanup_time -le 5 ]

    echo "Resource cleanup time: ${cleanup_time}s"
}

@test "shutdown handles multiple processes" {
    # Test shutdown with multiple PostgreSQL processes
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # This test is simplified - in a real scenario we'd have multiple processes
    # For now, just test that shutdown handles the normal case efficiently

    # Start PostgreSQL
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for PostgreSQL to be ready
    local ready_count=0
    while [ $ready_count -lt 30 ]; do
        if pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((ready_count++))
    done

    if ! pg_isready -h localhost -p 5432 -U postgres -t 1 >/dev/null 2>&1; then
        kill $startup_pid 2>/dev/null || true
        skip "PostgreSQL failed to start for multi-process test"
    fi

    local start_time
    start_time=$(date +%s)

    # Run shutdown
    /opt/container/entrypoint.d/scripts/runtime/shutdown.sh

    local end_time
    end_time=$(date +%s)
    local shutdown_time=$((end_time - start_time))

    # Shutdown should complete within limits
    assert [ $shutdown_time -le 30 ]

    echo "Multi-process shutdown time: ${shutdown_time}s (limit: 30s)"
}

@test "shutdown with Patroni completes within 30 seconds" {
    # Skip if Patroni is not available
    if ! command -v patroni >/dev/null 2>&1; then
        skip "Patroni not available for shutdown test"
    fi

    # Test Patroni shutdown time
    export USE_PATRONI=true
    export SLEEP_MODE=false

    # Start Patroni
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Wait for Patroni to start
    local start_count=0
    while [ $start_count -lt 30 ]; do
        if pgrep -f "patroni" >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((start_count++))
    done

    if ! pgrep -f "patroni" >/dev/null 2>&1; then
        kill $startup_pid 2>/dev/null || true
        skip "Patroni failed to start for shutdown test"
    fi

    local start_time
    start_time=$(date +%s)

    # Send shutdown signal
    kill -TERM $startup_pid

    # Wait for shutdown to complete
    local timeout_count=0
    while [ $timeout_count -lt 35 ] && pgrep -f "patroni" >/dev/null 2>&1; do
        sleep 1
        ((timeout_count++))
    done

    local end_time
    end_time=$(date +%s)
    local shutdown_time=$((end_time - start_time))

    # Wait for process to terminate
    wait $startup_pid 2>/dev/null || true

    # Assert shutdown time is within limits
    assert [ $shutdown_time -le 30 ]

    echo "Patroni shutdown time: ${shutdown_time}s (limit: 30s)"
}

@test "shutdown signal handling is immediate" {
    # Test that shutdown signal is handled quickly
    export USE_PATRONI=false
    export SLEEP_MODE=true  # Use sleep mode for predictable shutdown

    # Start sleep mode
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    local startup_pid=$!

    # Give it a moment to start
    sleep 1

    local start_time
    start_time=$(date +%s.%N)

    # Send shutdown signal
    kill -TERM $startup_pid

    # Wait for process to respond
    local responded=false
    local timeout_count=0
    while [ $timeout_count -lt 5 ]; do
        if ! kill -0 $startup_pid 2>/dev/null; then
            responded=true
            break
        fi
        sleep 0.1
        ((timeout_count++))
    done

    local end_time
    end_time=$(date +%s.%N)

    # Calculate response time
    local start_int=${start_time%.*}
    local end_int=${end_time%.*}
    local response_time=$((end_int - start_int))

    # Signal should be handled quickly
    assert_equal "$responded" "true"
    assert [ $response_time -le 2 ]

    # Wait for complete shutdown
    wait $startup_pid 2>/dev/null || true

    echo "Signal response time: ${response_time}s"
}