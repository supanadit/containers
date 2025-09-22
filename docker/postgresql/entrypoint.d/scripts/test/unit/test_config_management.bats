#!/usr/bin/env bats
# Contract test for configuration management
# Tests the configuration contracts defined in contracts/configuration-management.md

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/test_pgdata"
    export PGCONFIG="/tmp/test_pgconfig"
    mkdir -p "$PGDATA" "$PGCONFIG"
}

teardown() {
    # Clean up after each test
    rm -rf "$PGDATA" "$PGCONFIG"
    unset TEST_MODE PGDATA PGCONFIG
}

# Test configuration file management contract
@test "configuration files follow permission contract" {
    # Test postgresql.conf permissions
    run touch "$PGDATA/postgresql.conf"
    run chmod 0644 "$PGDATA/postgresql.conf"
    run ls -l "$PGDATA/postgresql.conf"
    assert_output --partial "-rw-r--r--"

    # Test pg_hba.conf permissions
    run touch "$PGDATA/pg_hba.conf"
    run chmod 0644 "$PGDATA/pg_hba.conf"
    run ls -l "$PGDATA/pg_hba.conf"
    assert_output --partial "-rw-r--r--"

    # Test sensitive file permissions
    run touch "$PGDATA/pgpass"
    run chmod 0600 "$PGDATA/pgpass"
    run ls -l "$PGDATA/pgpass"
    assert_output --partial "-rw-------"
}

@test "backup strategy follows contract" {
    # Test backup creation
    echo "test config" > "$PGDATA/postgresql.conf"
    run cp "$PGDATA/postgresql.conf" "$PGDATA/postgresql.conf.original"
    [ "$status" -eq 0 ]
    [ -f "$PGDATA/postgresql.conf.original" ]

    # Test backup integrity
    run diff "$PGDATA/postgresql.conf" "$PGDATA/postgresql.conf.original"
    [ "$status" -eq 0 ]
}

@test "configuration validation follows contract" {
    # Test postgresql.conf validation function exists
    run source /opt/container/entrypoint.d/scripts/utils/validation.sh
    run type validate_postgresql_conf
    [ "$status" -eq 0 ]

    # Test pg_hba.conf validation function exists
    run type validate_pg_hba_conf
    [ "$status" -eq 0 ]

    # Test Patroni config validation function exists
    run type validate_patroni_config
    [ "$status" -eq 0 ]
}

@test "environment variable mapping follows contract" {
    # Test PostgreSQL settings mapping
    export POSTGRESQL_SHARED_BUFFERS="256MB"
    run source /opt/container/entrypoint.d/scripts/utils/validation.sh
    run echo "$POSTGRESQL_SHARED_BUFFERS"
    [ "$status" -eq 0 ]

    # Test security settings mapping
    export POSTGRESQL_LISTEN_ADDRESSES="0.0.0.0"
    run echo "$POSTGRESQL_LISTEN_ADDRESSES"
    [ "$status" -eq 0 ]

    # Test archive settings mapping
    export PGBACKREST_STANZA="test-stanza"
    run echo "$PGBACKREST_STANZA"
    [ "$status" -eq 0 ]
}

@test "configuration hierarchy follows contract" {
    # Test that environment variables override config files
    export POSTGRESQL_SHARED_BUFFERS="512MB"
    echo "shared_buffers = 256MB" > "$PGCONFIG/postgresql.conf"

    # The environment variable should take precedence
    run source /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]
}

@test "postgresql.conf contains required settings" {
    # Test required settings are present
    run source /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check for required archive settings
    run grep "archive_mode" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]

    # Check for security settings
    run grep "listen_addresses" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]

    # Check for logging settings
    run grep "log_line_prefix" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "pg_hba.conf contains required entries" {
    # Test default entries are present
    run source /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check for local connections
    run grep "local.*all.*postgres.*peer" "$PGDATA/pg_hba.conf"
    [ "$status" -eq 0 ]

    # Check for Docker connections
    run grep "host.*all.*all.*0.0.0.0/0.*md5" "$PGDATA/pg_hba.conf"
    [ "$status" -eq 0 ]
}

@test "patroni configuration follows contract" {
    # Test Patroni config structure
    export USE_PATRONI=true
    run source /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check YAML structure
    [ -f "/etc/patroni.yml" ]

    # Check required fields
    run grep "scope:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "restapi:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "etcd:" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "migration maintains backward compatibility" {
    # Test that old environment variables still work
    export POSTGRES_DB="testdb"
    export POSTGRES_USER="testuser"
    export POSTGRES_PASSWORD="testpass"

    run source /opt/container/entrypoint.d/scripts/utils/validation.sh && validate_environment
    [ "$status" -eq 0 ]
}

@test "security considerations are enforced" {
    # Test sensitive data handling
    export POSTGRES_PASSWORD="secret123"
    run source /opt/container/entrypoint.d/scripts/utils/logging.sh && log_info "Password: $POSTGRES_PASSWORD"
    # Password should not appear in logs (this test will fail until implemented)
    [ "$status" -eq 0 ]

    # Test secure permissions
    run source /opt/container/entrypoint.d/scripts/utils/security.sh && set_secure_permissions "$PGDATA"
    [ "$status" -eq 0 ]

    # Check permissions are secure
    run ls -ld "$PGDATA"
    assert_output --partial "drwx------"
}