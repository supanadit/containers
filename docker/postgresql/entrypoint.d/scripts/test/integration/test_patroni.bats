#!/usr/bin/env bats
# Integration test for Patroni mode
# Tests Patroni-specific functionality and configuration

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/test_pgdata"
    export LOG_LEVEL=DEBUG
    export USE_PATRONI=true
    mkdir -p "$PGDATA"
}

teardown() {
    # Clean up after each test
    rm -rf "$PGDATA"
    unset TEST_MODE PGDATA LOG_LEVEL USE_PATRONI
    # Kill any test processes
    pkill -f "patroni" || true
    pkill -f "postgres" || true
}

@test "Patroni starts with correct configuration" {
    # Test Patroni startup
    run /opt/container/entrypoint.d/scripts/runtime/startup.sh
    [ "$status" -eq 0 ]

    # Check Patroni process is running
    run pgrep -f "patroni"
    [ "$status" -eq 0 ]
}

@test "Patroni configuration contains required fields" {
    # Test Patroni config structure
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    [ -f "/etc/patroni.yml" ]

    # Check required configuration sections
    run grep "scope:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "name:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "restapi:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "etcd:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "bootstrap:" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni uses correct PostgreSQL data directory" {
    # Test data directory configuration
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check data_dir in Patroni config
    run grep "data_dir: $PGDATA" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni configures proper authentication" {
    # Test authentication configuration
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check authentication section exists
    run grep "authentication:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    # Check replication user
    run grep "replicator:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    # Check superuser
    run grep "superuser:" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni sets correct PostgreSQL parameters" {
    # Test PostgreSQL parameter configuration
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check parameters section
    run grep "parameters:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    # Check replication settings
    run grep "wal_level: replica" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "hot_standby.*on" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni configures archive settings" {
    # Test WAL archiving configuration
    export BACKUP_ENABLED=true

    run /opt/container/entrypoint.d/scripts/init/04-backup.sh
    [ "$status" -eq 0 ]

    # Check archive settings in Patroni config
    run grep "archive_mode.*on" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "pgbackrest" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni handles etcd connectivity" {
    # Test etcd configuration
    export ETCD_HOST="localhost"
    export ETCD_PORT="2379"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check etcd configuration
    run grep "host: localhost:2379" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni sets proper timeouts" {
    # Test timeout configuration
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check DCS timeouts
    run grep "ttl: 30" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "loop_wait: 10" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni startup waits for etcd" {
    # Test etcd dependency handling
    export ETCD_UNAVAILABLE=true

    run timeout 10 /opt/container/entrypoint.d/scripts/runtime/startup.sh
    # Should either succeed (if etcd available) or timeout gracefully
    [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
}

@test "Patroni handles cluster name configuration" {
    # Test cluster scope configuration
    export PATRONI_SCOPE="test-cluster"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    run grep "scope: test-cluster" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni configures REST API" {
    # Test REST API configuration
    export PATRONI_REST_PORT="8008"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check REST API settings
    run grep "listen: 0.0.0.0:8008" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "connect_address: localhost:8008" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni sets node name" {
    # Test node name configuration
    export PATRONI_NAME="test-node-01"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    run grep "name: test-node-01" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "Patroni handles shutdown gracefully" {
    # Test Patroni shutdown
    /opt/container/entrypoint.d/scripts/runtime/startup.sh &
    STARTUP_PID=$!

    sleep 5  # Give Patroni time to start

    kill -TERM $STARTUP_PID
    wait $STARTUP_PID 2>/dev/null || true

    # Patroni should not be running
    run pgrep -f "patroni"
    [ "$status" -ne 0 ]
}

@test "Patroni validates configuration before startup" {
    # Test configuration validation
    export INVALID_PATRONI_CONFIG=true

    run /opt/container/entrypoint.d/scripts/runtime/startup.sh
    [ "$status" -ne 0 ]  # Should fail with invalid config
}

@test "Patroni supports custom PostgreSQL port" {
    # Test custom port configuration
    export POSTGRESQL_PORT="5433"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check port in Patroni config
    run grep "listen: 0.0.0.0:5433" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "connect_address: localhost:5433" /etc/patroni.yml
    [ "$status" -eq 0 ]
}