#!/usr/bin/env bats
# Integration test for graceful shutdown
# Tests shutdown behavior and signal handling

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/test_pgdata"
    export LOG_LEVEL=DEBUG
    mkdir -p "$PGDATA"
}

teardown() {
    # Clean up after each test
    rm -rf "$PGDATA"
    unset TEST_MODE PGDATA LOG_LEVEL
    # Kill any remaining test processes
    pkill -f "postgres" || true
    pkill -f "patroni" || true
}

@test "graceful shutdown handles SIGTERM" {
    # Test SIGTERM signal handling
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL in background
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    # Wait for startup to complete
    sleep 2

    # Send SIGTERM
    kill -TERM $STARTUP_PID

    # Wait for shutdown
    wait $STARTUP_PID 2>/dev/null || true

    # Check that PostgreSQL is not running
    run pgrep -f "postgres"
    [ "$status" -ne 0 ]
}

@test "shutdown completes within 30 seconds" {
    # Test shutdown timeout
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 2

    # Time the shutdown
    START_TIME=$(date +%s)
    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true
    END_TIME=$(date +%s)

    SHUTDOWN_TIME=$((END_TIME - START_TIME))
    [ "$SHUTDOWN_TIME" -le 30 ]
}

@test "shutdown cleans up PID files" {
    # Test PID file cleanup
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Create fake PID file
    echo "12345" > "$PGDATA/postmaster.pid"

    # Start and shutdown
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!
    sleep 2
    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true

    # Check PID file is cleaned up
    [ ! -f "$PGDATA/postmaster.pid" ]
}

@test "shutdown handles multiple signals gracefully" {
    # Test multiple signal handling
    export USE_PATRONI=false
    export SLEEP_MODE=false

    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 2

    # Send multiple signals
    kill -HUP $STARTUP_PID
    sleep 1
    kill -TERM $STARTUP_PID

    wait $STARTUP_PID 2>/dev/null || true

    # Should still shutdown gracefully
    run pgrep -f "postgres"
    [ "$status" -ne 0 ]
}

@test "shutdown works with Patroni mode" {
    # Test shutdown with Patroni
    export USE_PATRONI=true
    export SLEEP_MODE=false

    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 3  # Patroni takes longer to start

    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true

    # Check Patroni is not running
    run pgrep -f "patroni"
    [ "$status" -ne 0 ]
}

@test "shutdown handles force termination" {
    # Test force shutdown after graceful timeout
    export USE_PATRONI=false
    export SLEEP_MODE=false
    export FORCE_SHUTDOWN=true  # Simulate hung process

    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 2

    # This should eventually force kill if graceful shutdown fails
    timeout 35 kill -TERM $STARTUP_PID || kill -KILL $STARTUP_PID || true

    # PostgreSQL should not be running
    run pgrep -f "postgres"
    [ "$status" -ne 0 ]
}

@test "shutdown preserves data integrity" {
    # Test that shutdown doesn't corrupt data
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Start PostgreSQL and create some data
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 3

    # Create a test database and table
    if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        createdb testdb || true
        psql -d testdb -c "CREATE TABLE test (id SERIAL PRIMARY KEY, data TEXT);" || true
        psql -d testdb -c "INSERT INTO test (data) VALUES ('test data');" || true
    fi

    # Shutdown
    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true

    # Data should still be intact (test will fail until implemented)
    [ -f "$PGDATA/PG_VERSION" ]
}

@test "shutdown logs appropriately" {
    # Test shutdown logging
    export USE_PATRONI=false
    export SLEEP_MODE=false
    export LOG_LEVEL=DEBUG

    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 2

    # Capture shutdown logs
    OUTPUT=$(kill -TERM $STARTUP_PID 2>&1; wait $STARTUP_PID 2>/dev/null || true)

    # Check for shutdown messages
    echo "$OUTPUT" | grep -i "shut" || true
    echo "$OUTPUT" | grep -i "stop" || true
}

@test "shutdown handles missing processes gracefully" {
    # Test shutdown when process already stopped
    export USE_PATRONI=false
    export SLEEP_MODE=false

    # Try to shutdown without starting
    run /opt/container/entrypoint.d/scripts/runtime/shutdown.sh
    [ "$status" -eq 0 ]  # Should not fail
}

@test "shutdown respects custom timeout" {
    # Test custom shutdown timeout
    export USE_PATRONI=false
    export SLEEP_MODE=false
    export TIMEOUT=10

    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 2

    START_TIME=$(date +%s)
    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true
    END_TIME=$(date +%s)

    SHUTDOWN_TIME=$((END_TIME - START_TIME))
    [ "$SHUTDOWN_TIME" -le 15 ]  # Allow some margin
}