# Test fixtures for PostgreSQL container testing
# Sample configuration files and test data

# Sample postgresql.conf for testing
cat > /opt/container/entrypoint.d/scripts/test/fixtures/sample_postgresql.conf << 'EOF'
# Sample PostgreSQL configuration for testing
listen_addresses = 'localhost'
port = 5432
max_connections = 100
shared_buffers = 128MB
effective_cache_size = 512MB
maintenance_work_mem = 32MB
work_mem = 2MB
wal_level = replica
archive_mode = off
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_statement = 'ddl'
log_duration = on
timezone = 'UTC'
EOF

# Sample pg_hba.conf for testing
cat > /opt/container/entrypoint.d/scripts/test/fixtures/sample_pg_hba.conf << 'EOF'
# Sample pg_hba configuration for testing
local   all             postgres                                trust
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

# Sample Patroni configuration for testing
cat > /opt/container/entrypoint.d/scripts/test/fixtures/sample_patroni.yml << 'EOF'
# Sample Patroni configuration for testing
scope: test-cluster
name: test-node-1
restapi:
  listen: 0.0.0.0:8008
  connect_address: localhost:8008
etcd:
  host: localhost:2379
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        logging_collector: "on"
        max_wal_senders: 10
        max_replications_slots: 10
        wal_keep_segments: 8
postgresql:
  listen: 0.0.0.0:5432
  connect_address: localhost:5432
  data_dir: /tmp/test_pgdata
  config_dir: /tmp/test_pgdata
  authentication:
    replication:
      username: replicator
      password: replicator_password
    superuser:
      username: postgres
      password: test_password
EOF

# Sample pgBackRest configuration for testing
cat > /opt/container/entrypoint.d/scripts/test/fixtures/sample_pgbackrest.conf << 'EOF'
# Sample pgBackRest configuration for testing
[global]
repo1-path=/tmp/test_backup
repo1-retention-full=2
log-level-console=info

[test-stanza]
pg1-path=/tmp/test_pgdata
pg1-port=5432
pg1-user=postgres
EOF

# Sample environment variables for testing
cat > /opt/container/entrypoint.d/scripts/test/fixtures/test_env.sh << 'EOF'
# Sample environment variables for testing
export TEST_MODE=true
export PGDATA=/tmp/test_pgdata
export PGCONFIG=/tmp/test_config
export LOG_LEVEL=DEBUG
export USE_PATRONI=false
export SLEEP_MODE=false
export BACKUP_ENABLED=false
export TIMEOUT=30
export POSTGRES_USER=postgres
export POSTGRES_GROUP=postgres
EOF

echo "Test fixtures created successfully"