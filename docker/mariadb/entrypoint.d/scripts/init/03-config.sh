#!/bin/bash
# 03-config.sh - Configuration setup for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

log_script_start "03-config.sh"

export MARIADB_CONFIG_DIR="${MARIADB_CONFIG_DIR:-/etc/mysql/mariadb.conf.d}"
export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"

# Create configuration directory
mkdir -p "$MARIADB_CONFIG_DIR"

# Main configuration file
cat > "$MARIADB_CONFIG_DIR/z-mariadb-custom.cnf" << EOF
[mysqld]
# Data directory
datadir=${MARIADB_DATA_DIR}
skip-name-resolve

# Logging
log_error=/var/log/mariadb/error.log
slow_query_log=1
slow_query_log_file=/var/log/mariadb/slow-query.log
long_query_time=2

# Character set
character_set_server=utf8mb4
collation_server=utf8mb4_unicode_ci

# Connection settings
max_connections=${MARIADB_MAX_CONNECTIONS:-200}
max_connect_errors=100000
max_allowed_packet=128M

# Buffer settings
innodb_buffer_pool_size=${MARIADB_INNODB_BUFFER_POOL_SIZE:-128M}
innodb_log_file_size=${MARIADB_INNODB_LOG_FILE_SIZE:-48M}
innodb_flush_log_at_trx_commit=${MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT:-1}
innodb_flush_method=O_DIRECT

# Query cache (MariaDB 10.1+)
query_cache_type=1
query_cache_size=64M
query_cache_limit=2M

# Galera settings
wsrep_on=${MARIADB_GALERA_ENABLE:-false}
wsrep_provider=${MARIADB_GALERA_PROVIDER:-none}
wsrep_cluster_name=${MARIADB_GALERA_CLUSTER_NAME:-mariadb_cluster}
wsrep_cluster_address=${MARIADB_GALERA_SEEDS:-}
wsrep_sst_method=${MARIADB_GALERA_SST_METHOD:-xtrabackup}
wsrep_node_address=${MARIADB_NODE_ADDRESS:-localhost}
wsrep_slave_threads=${MARIADB_GALERA_THREADS:-4}

# Replication settings
log_bin=/var/log/mariadb/mysql-bin
binlog_format=row
sync_binlog=1
expire_logs_days=${MARIADB_EXPIRE_LOGS_DAYS:-7}

# SSL settings
ssl=${MARIADB_SSL_ENABLE:-false}
ssl_cert=${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}/server.crt
ssl_key=${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}/server.key
ssl_ca=${MARIADB_SSL_CERT_DIR:-/var/lib/mysql/ssl}/ca.crt

# Performance settings
innodb_io_capacity=2000
innodb_io_capacity_max=4000
innodb_read_io_threads=8
innodb_write_io_threads=8
innodb_thread_concurrency=0

# Timezone
default_time_zone=${MARIADB_TIMEZONE:-UTC}

# Temp tables
tmpdir=/tmp
max_heap_table_size=256M
tmp_table_size=256M

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF

chown mysql:mysql "$MARIADB_CONFIG_DIR/z-mariadb-custom.cnf"
chmod 0644 "$MARIADB_CONFIG_DIR/z-mariadb-custom.cnf"

log_info "MariaDB configuration created at $MARIADB_CONFIG_DIR/z-mariadb-custom.cnf"

log_script_end "03-config.sh"