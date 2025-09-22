#!/usr/bin/env bats
# Integration test for configuration handling
# Tests configuration file processing and validation

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Set up test environment
    export TEST_MODE=true
    export PGDATA="/tmp/test_pgdata"
    export PGCONFIG="/tmp/test_pgconfig"
    export LOG_LEVEL=DEBUG
    mkdir -p "$PGDATA" "$PGCONFIG"
}

teardown() {
    # Clean up after each test
    rm -rf "$PGDATA" "$PGCONFIG"
    unset TEST_MODE PGDATA PGCONFIG LOG_LEVEL
}

@test "configuration files are processed in correct order" {
    # Test configuration hierarchy
    export POSTGRESQL_SHARED_BUFFERS="512MB"
    echo "shared_buffers = 256MB" > "$PGCONFIG/postgresql.conf"
    echo "shared_buffers = 128MB" > "$PGDATA/postgresql.conf.template"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Environment variable should override config file
    run grep "shared_buffers = 512MB" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "custom postgresql.conf is applied correctly" {
    # Test custom configuration application
    cat > "$PGCONFIG/postgresql.conf" << EOF
shared_buffers = 256MB
max_connections = 200
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
EOF

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check custom settings are applied
    run grep "shared_buffers = 256MB" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]

    run grep "max_connections = 200" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "custom pg_hba.conf is applied correctly" {
    # Test custom HBA configuration
    cat > "$PGCONFIG/pg_hba.conf" << EOF
local   all             postgres                                trust
host    all             all             192.168.1.0/24         md5
host    all             all             0.0.0.0/0               reject
EOF

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check custom HBA rules are applied
    run grep "192.168.1.0/24" "$PGDATA/pg_hba.conf"
    [ "$status" -eq 0 ]

    run grep "reject" "$PGDATA/pg_hba.conf"
    [ "$status" -eq 0 ]
}

@test "configuration validation catches syntax errors" {
    # Test configuration validation
    echo "invalid_syntax = broken" > "$PGCONFIG/postgresql.conf"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -ne 0 ]  # Should fail with syntax error
}

@test "backup files are created correctly" {
    # Test backup creation
    echo "original_setting = value" > "$PGDATA/postgresql.conf"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check backup was created
    [ -f "$PGDATA/postgresql.conf.original" ]

    # Check backup content
    run grep "original_setting = value" "$PGDATA/postgresql.conf.original"
    [ "$status" -eq 0 ]
}

@test "environment variables override config files" {
    # Test environment variable precedence
    export POSTGRESQL_MAX_CONNECTIONS=300
    echo "max_connections = 100" > "$PGCONFIG/postgresql.conf"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Environment variable should take precedence
    run grep "max_connections = 300" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "security settings are applied by default" {
    # Test default security settings
    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check security settings
    run grep "listen_addresses = '*'" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]

    run grep "log_statement = 'ddl'" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "archive settings are configured when backup enabled" {
    # Test archive configuration
    export BACKUP_ENABLED=true

    run /opt/container/entrypoint.d/scripts/init/04-backup.sh
    [ "$status" -eq 0 ]

    # Check archive settings in postgresql.conf
    run grep "archive_mode = on" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]

    run grep "pgbackrest" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "Patroni configuration is generated correctly" {
    # Test Patroni config generation
    export USE_PATRONI=true

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Check Patroni config exists
    [ -f "/etc/patroni.yml" ]

    # Check required sections
    run grep "scope:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "postgresql:" /etc/patroni.yml
    [ "$status" -eq 0 ]

    run grep "etcd:" /etc/patroni.yml
    [ "$status" -eq 0 ]
}

@test "configuration handles missing config directory" {
    # Test graceful handling of missing config directory
    rm -rf "$PGCONFIG"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]  # Should not fail

    # Should still create basic configuration
    [ -f "$PGDATA/postgresql.conf" ]
    [ -f "$PGDATA/pg_hba.conf" ]
}

@test "configuration validates file permissions" {
    # Test permission validation
    echo "test" > "$PGCONFIG/postgresql.conf"
    chmod 777 "$PGCONFIG/postgresql.conf"

    export STRICT_PERMISSIONS=true

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -ne 0 ]  # Should fail with permission error
}

@test "configuration supports multiple database versions" {
    # Test version-specific configuration
    export PG_MAJOR_VERSION="13"

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Should handle version-specific settings
    run grep "wal_level" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}

@test "configuration handles large config files" {
    # Test handling of large configuration files
    for i in {1..1000}; do
        echo "setting_$i = value_$i" >> "$PGCONFIG/postgresql.conf"
    done

    run /opt/container/entrypoint.d/scripts/init/03-config.sh
    [ "$status" -eq 0 ]

    # Should process all settings
    run grep "setting_1000 = value_1000" "$PGDATA/postgresql.conf"
    [ "$status" -eq 0 ]
}