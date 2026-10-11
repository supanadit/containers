// env.js — MariaDB environment configuration.
//
// Single source of truth for every environment-driven setting. Every name
// exported here is consumed by at least one bootstrap module; booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy
// and would silently enable wsrep/SSL).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const MARIADB_DATA_DIR = env.get("MARIADB_DATA_DIR", "/opt/containers/data");
const MARIADB_LOG_DIR = env.get("MARIADB_LOG_DIR", "/opt/containers/logs");
const MARIADB_RUN_DIR = env.get("MARIADB_RUN_DIR", "/opt/containers/run");
const MARIADB_CONFIG_DIR = env.get("MARIADB_CONFIG_DIR", "/opt/containers/config");
const MARIADB_BACKUP_DIR = env.get("MARIADB_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Core settings
// ---------------------------------------------------------------------------
const MARIADB_ROOT_PASSWORD = env.get("MARIADB_ROOT_PASSWORD", "");
const MARIADB_DATABASE = env.get("MARIADB_DATABASE", "");
const MARIADB_USER = env.get("MARIADB_USER", "");
const MARIADB_PASSWORD = env.get("MARIADB_PASSWORD", "");
const MARIADB_ALLOW_EMPTY_PASSWORD = env.get("MARIADB_ALLOW_EMPTY_PASSWORD", "no");
const MARIADB_PORT = env.get("MARIADB_PORT", "3306");
const MARIADB_BIND_ADDRESS = env.get("MARIADB_BIND_ADDRESS", "0.0.0.0");
const MARIADB_WAIT_TIMEOUT = env.get("MARIADB_WAIT_TIMEOUT", "300");
const MARIADB_MAX_CONNECTIONS = env.get("MARIADB_MAX_CONNECTIONS", "151");
const MARIADB_MAX_ALLOWED_PACKET = env.get("MARIADB_MAX_ALLOWED_PACKET", "256M");
const MARIADB_KEY_BUFFER_SIZE = env.get("MARIADB_KEY_BUFFER_SIZE", "16M");

const MARIADB_INNODB_BUFFER_POOL_SIZE = env.get("MARIADB_INNODB_BUFFER_POOL_SIZE", "256M");
const MARIADB_INNODB_LOG_FILE_SIZE = env.get("MARIADB_INNODB_LOG_FILE_SIZE", "64M");
const MARIADB_INNODB_FLUSH_METHOD = env.get("MARIADB_INNODB_FLUSH_METHOD", "O_DIRECT");
const MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT = env.get("MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT", "1");
const MARIADB_INNODB_FILE_PER_TABLE = env.get("MARIADB_INNODB_FILE_PER_TABLE", "1");

const MARIADB_LOG_BIN = env.get("MARIADB_LOG_BIN", "1");
const MARIADB_EXPIRE_LOGS_DAYS = env.get("MARIADB_EXPIRE_LOGS_DAYS", "7");
const MARIADB_SLOW_QUERY_LOG = env.get("MARIADB_SLOW_QUERY_LOG", "1");
const MARIADB_LONG_QUERY_TIME = env.get("MARIADB_LONG_QUERY_TIME", "2");
const MARIADB_CHARACTER_SET_SERVER = env.get("MARIADB_CHARACTER_SET_SERVER", "utf8mb4");
const MARIADB_COLLATION_SERVER = env.get("MARIADB_COLLATION_SERVER", "utf8mb4_unicode_ci");
const MARIADB_TIMEZONE = env.get("MARIADB_TIMEZONE", "SYSTEM");
const MARIADB_QUERY_CACHE_SIZE = env.get("MARIADB_QUERY_CACHE_SIZE", "0");
const MARIADB_QUERY_CACHE_LIMIT = env.get("MARIADB_QUERY_CACHE_LIMIT", "2M");

// ---------------------------------------------------------------------------
// TLS
// ---------------------------------------------------------------------------
const MARIADB_SSL_ENABLE = env.bool("MARIADB_SSL_ENABLE", false);
const MARIADB_SSL_CERT_DIR = env.get("MARIADB_SSL_CERT_DIR", MARIADB_CONFIG_DIR + "/ssl");

// ---------------------------------------------------------------------------
// Galera Cluster
// ---------------------------------------------------------------------------
const MARIADB_GALERA_ENABLE = env.bool("MARIADB_GALERA_ENABLE", false);
const MARIADB_GALERA_PROVIDER = env.get("MARIADB_GALERA_PROVIDER", "/usr/local/lib/libgalera_smm.so");
const MARIADB_GALERA_CLUSTER_NAME = env.get("MARIADB_GALERA_CLUSTER_NAME", "galera_cluster");
const MARIADB_GALERA_SEEDS = env.get("MARIADB_GALERA_SEEDS", "");
const MARIADB_GALERA_SST_METHOD = env.get("MARIADB_GALERA_SST_METHOD", "mariabackup");
const MARIADB_GALERA_THREADS = env.get("MARIADB_GALERA_THREADS", "4");
const MARIADB_GALERA_SERVER_ID = env.get("MARIADB_GALERA_SERVER_ID", "1");
const MARIADB_NODE_ADDRESS = env.get("MARIADB_NODE_ADDRESS", "");

// ---------------------------------------------------------------------------
// MaxScale service account (database.js creates it only when both are set)
// ---------------------------------------------------------------------------
const MAXSCALE_SERVICE_USER = env.get("MAXSCALE_SERVICE_USER", "");
const MAXSCALE_SERVICE_PASSWORD = env.get("MAXSCALE_SERVICE_PASSWORD", "");

// ---------------------------------------------------------------------------
// Backup (backup.js). MARIADB_BACKUP_ENABLE gates the scheduled node in
// runtime.js; the rest configure the method, retention and optional uploads.
// ---------------------------------------------------------------------------
const MARIADB_BACKUP_ENABLE = env.bool("MARIADB_BACKUP_ENABLE");
const MARIADB_BACKUP_METHOD = env.get("MARIADB_BACKUP_METHOD", "mariabackup");
// MARIADB_BACKUP_SCHEDULE drives the FULL backup (chain base);
// MARIADB_BACKUP_INCR_SCHEDULE, when set, drives incremental backups that
// extend the newest chain. Empty incr schedule = full-only (pre-chain
// behaviour), so existing deployments are unaffected.
const MARIADB_BACKUP_SCHEDULE = env.get("MARIADB_BACKUP_SCHEDULE", "0 2 * * *");
const MARIADB_BACKUP_INCR_SCHEDULE = env.get("MARIADB_BACKUP_INCR_SCHEDULE", "");
const MARIADB_BACKUP_TIMEZONE = env.get("MARIADB_BACKUP_TIMEZONE", "UTC");
const MARIADB_BACKUP_RETENTION_DAYS = env.get("MARIADB_BACKUP_RETENTION_DAYS", "7");
const MARIADB_BACKUP_S3_BUCKET = env.get("MARIADB_BACKUP_S3_BUCKET", "");
const MARIADB_BACKUP_S3_REGION = env.get("MARIADB_BACKUP_S3_REGION", "us-east-1");
const MARIADB_BACKUP_S3_ENDPOINT = env.get("MARIADB_BACKUP_S3_ENDPOINT", "");
const MARIADB_BACKUP_SFTP_HOST = env.get("MARIADB_BACKUP_SFTP_HOST", "");
const MARIADB_BACKUP_SFTP_PORT = env.get("MARIADB_BACKUP_SFTP_PORT", "22");
const MARIADB_BACKUP_SFTP_USER = env.get("MARIADB_BACKUP_SFTP_USER", "backup");
const MARIADB_BACKUP_SFTP_KEY = env.get("MARIADB_BACKUP_SFTP_KEY", "");
const MARIADB_BACKUP_SFTP_DEST = env.get("MARIADB_BACKUP_SFTP_DEST", "/backups");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE");

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const MARIADB_SOCKET = MARIADB_RUN_DIR + "/mysqld.sock";
const MARIADB_PID_FILE = MARIADB_RUN_DIR + "/mysqld.pid";
const MARIADB_CONFIG_FILE = MARIADB_CONFIG_DIR + "/my.cnf";
// Timezone-table SQL generated at image build time by forge.toml
// (mysql_tzinfo_to_sql over /usr/share/zoneinfo). Baked in because ezx's
// process.capture caps one stream at 1 MiB and the full dump is ~4.8 MB.
const MARIADB_TZDATA_SQL = env.get("MARIADB_TZDATA_SQL", "/opt/container/mariadb-tzdata.sql");

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const MARIADB_READY_MAX_ATTEMPTS = env.get("MARIADB_READY_MAX_ATTEMPTS", "30");
const MARIADB_READY_ATTEMPT_INTERVAL = env.get("MARIADB_READY_ATTEMPT_INTERVAL", "1");

module.exports = {
  // directories
  MARIADB_DATA_DIR,
  MARIADB_LOG_DIR,
  MARIADB_RUN_DIR,
  MARIADB_CONFIG_DIR,
  MARIADB_BACKUP_DIR,
  // core
  MARIADB_ROOT_PASSWORD,
  MARIADB_DATABASE,
  MARIADB_USER,
  MARIADB_PASSWORD,
  MARIADB_ALLOW_EMPTY_PASSWORD,
  MARIADB_PORT,
  MARIADB_BIND_ADDRESS,
  MARIADB_WAIT_TIMEOUT,
  MARIADB_MAX_CONNECTIONS,
  MARIADB_MAX_ALLOWED_PACKET,
  MARIADB_KEY_BUFFER_SIZE,
  MARIADB_INNODB_BUFFER_POOL_SIZE,
  MARIADB_INNODB_LOG_FILE_SIZE,
  MARIADB_INNODB_FLUSH_METHOD,
  MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT,
  MARIADB_INNODB_FILE_PER_TABLE,
  MARIADB_LOG_BIN,
  MARIADB_EXPIRE_LOGS_DAYS,
  MARIADB_SLOW_QUERY_LOG,
  MARIADB_LONG_QUERY_TIME,
  MARIADB_CHARACTER_SET_SERVER,
  MARIADB_COLLATION_SERVER,
  MARIADB_TIMEZONE,
  MARIADB_QUERY_CACHE_SIZE,
  MARIADB_QUERY_CACHE_LIMIT,
  // tls
  MARIADB_SSL_ENABLE,
  MARIADB_SSL_CERT_DIR,
  // galera
  MARIADB_GALERA_ENABLE,
  MARIADB_GALERA_PROVIDER,
  MARIADB_GALERA_CLUSTER_NAME,
  MARIADB_GALERA_SEEDS,
  MARIADB_GALERA_SST_METHOD,
  MARIADB_GALERA_THREADS,
  MARIADB_GALERA_SERVER_ID,
  MARIADB_NODE_ADDRESS,
  // maxscale
  MAXSCALE_SERVICE_USER,
  MAXSCALE_SERVICE_PASSWORD,
  // backup
  MARIADB_BACKUP_ENABLE,
  MARIADB_BACKUP_METHOD,
  MARIADB_BACKUP_SCHEDULE,
  MARIADB_BACKUP_INCR_SCHEDULE,
  MARIADB_BACKUP_TIMEZONE,
  MARIADB_BACKUP_RETENTION_DAYS,
  MARIADB_BACKUP_S3_BUCKET,
  MARIADB_BACKUP_S3_REGION,
  MARIADB_BACKUP_S3_ENDPOINT,
  MARIADB_BACKUP_SFTP_HOST,
  MARIADB_BACKUP_SFTP_PORT,
  MARIADB_BACKUP_SFTP_USER,
  MARIADB_BACKUP_SFTP_KEY,
  MARIADB_BACKUP_SFTP_DEST,
  // misc
  SLEEP_MODE,
  // derived paths
  MARIADB_SOCKET,
  MARIADB_PID_FILE,
  MARIADB_CONFIG_FILE,
  MARIADB_TZDATA_SQL,
  // readiness
  MARIADB_READY_MAX_ATTEMPTS,
  MARIADB_READY_ATTEMPT_INTERVAL,
};
