// env.js — PgPool-II environment configuration.
//
// Single source of truth for every environment-driven setting. Every name
// exported here is consumed by at least one bootstrap module. Booleans use
// env.bool() so they arrive as real JS booleans (the string "off"/"false" is
// truthy and would silently enable watchdog/SSL/memory-cache).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const PGPOOL_CONFIG_DIR = env.get("PGPOOL_CONFIG_DIR", "/opt/containers/config");
const PGPOOL_LOG_DIR = env.get("PGPOOL_LOG_DIR", "/opt/containers/logs");
const PGPOOL_RUN_DIR = env.get("PGPOOL_RUN_DIR", "/opt/containers/run");
const PGPOOL_USER = env.get("PGPOOL_USER", "postgres");
const PGPOOL_GROUP = env.get("PGPOOL_GROUP", "postgres");

// ---------------------------------------------------------------------------
// Core ports
// ---------------------------------------------------------------------------
const PGPOOL_PORT = env.get("PGPOOL_PORT", "5432");
const PGPOOL_PCP_PORT = env.get("PGPOOL_PCP_PORT", "9898");

// ---------------------------------------------------------------------------
// SSL/TLS
// ---------------------------------------------------------------------------
const PGPOOL_SSL = env.bool("PGPOOL_SSL", false);
const PGPOOL_SSL_KEY = env.get("PGPOOL_SSL_KEY", "");
const PGPOOL_SSL_CERT = env.get("PGPOOL_SSL_CERT", "");
const PGPOOL_SSL_SECURITY_MODE = env.get("PGPOOL_SSL_SECURITY_MODE", "postgresql");

// ---------------------------------------------------------------------------
// Backends. PGPOOL_BACKENDS is required: "host:port,host:port,...".
// ---------------------------------------------------------------------------
const PGPOOL_BACKENDS = env.get("PGPOOL_BACKENDS", "");
const PGPOOL_BACKEND_WEIGHTS = env.get("PGPOOL_BACKEND_WEIGHTS", "");
const PGPOOL_BACKEND_FLAGS = env.get("PGPOOL_BACKEND_FLAGS", "");

// ---------------------------------------------------------------------------
// Patroni integration (kept for user scripts; no longer drives config)
// ---------------------------------------------------------------------------
const PGPOOL_PATRONI_ENDPOINTS = env.get("PGPOOL_PATRONI_ENDPOINTS", "");
const PGPOOL_PATRONI_TIMEOUT = env.get("PGPOOL_PATRONI_TIMEOUT", "10");

// ---------------------------------------------------------------------------
// Pool configuration
// ---------------------------------------------------------------------------
const PGPOOL_NUM_INIT_CHILDREN = env.get("PGPOOL_NUM_INIT_CHILDREN", "32");
const PGPOOL_MAX_POOL = env.get("PGPOOL_MAX_POOL", "4");
const PGPOOL_CHILD_LIFE_TIME = env.get("PGPOOL_CHILD_LIFE_TIME", "300");
const PGPOOL_CONNECTION_LIFE_TIME = env.get("PGPOOL_CONNECTION_LIFE_TIME", "0");
const PGPOOL_CHILD_MAX_CONNECTIONS = env.get("PGPOOL_CHILD_MAX_CONNECTIONS", "0");

// ---------------------------------------------------------------------------
// Load balancing
// ---------------------------------------------------------------------------
const PGPOOL_LOAD_BALANCE_MODE = env.get("PGPOOL_LOAD_BALANCE_MODE", "on");
const PGPOOL_IGNORE_LEADING_WHITE_SPACE = env.get("PGPOOL_IGNORE_LEADING_WHITE_SPACE", "on");

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------
const PGPOOL_ENABLE_POOL_HBA = env.bool("PGPOOL_ENABLE_POOL_HBA");
const PGPOOL_POOL_PASSWD = env.get("PGPOOL_POOL_PASSWD", "pool_passwd");
const PGPOOL_BACKEND_USER = env.get("PGPOOL_BACKEND_USER", "postgres");
const PGPOOL_BACKEND_PASSWORD = env.get("PGPOOL_BACKEND_PASSWORD", "");

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------
const PGPOOL_HEALTH_CHECK_TIMEOUT = env.get("PGPOOL_HEALTH_CHECK_TIMEOUT", "5");
const PGPOOL_HEALTH_CHECK_PERIOD = env.get("PGPOOL_HEALTH_CHECK_PERIOD", "10");
const PGPOOL_HEALTH_CHECK_USER = env.get("PGPOOL_HEALTH_CHECK_USER", PGPOOL_BACKEND_USER);
const PGPOOL_HEALTH_CHECK_PASSWORD = env.get("PGPOOL_HEALTH_CHECK_PASSWORD", PGPOOL_BACKEND_PASSWORD);
const PGPOOL_HEALTH_CHECK_DATABASE = env.get("PGPOOL_HEALTH_CHECK_DATABASE", "postgres");
const PGPOOL_HEALTH_CHECK_MAX_RETRIES = env.get("PGPOOL_HEALTH_CHECK_MAX_RETRIES", "0");
const PGPOOL_HEALTH_CHECK_RETRY_DELAY = env.get("PGPOOL_HEALTH_CHECK_RETRY_DELAY", "1");
const PGPOOL_CONNECT_TIMEOUT = env.get("PGPOOL_CONNECT_TIMEOUT", "10000");

// ---------------------------------------------------------------------------
// PCP (PgPool Control Protocol)
// ---------------------------------------------------------------------------
const PGPOOL_PCP_TIMEOUT = env.get("PGPOOL_PCP_TIMEOUT", "10");
const PGPOOL_PCP_NUM_CHILDREN = env.get("PGPOOL_PCP_NUM_CHILDREN", "32");

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
const PGPOOL_LOG_MIN_MESSAGES = env.get("PGPOOL_LOG_MIN_MESSAGES", "warning");
const PGPOOL_LOG_HOSTNAME = env.get("PGPOOL_LOG_HOSTNAME", "on");

// ---------------------------------------------------------------------------
// Streaming replication check
// ---------------------------------------------------------------------------
const PGPOOL_SR_CHECK_PERIOD = env.get("PGPOOL_SR_CHECK_PERIOD", "10");
const PGPOOL_SR_CHECK_USER = env.get("PGPOOL_SR_CHECK_USER", PGPOOL_BACKEND_USER);
const PGPOOL_SR_CHECK_PASSWORD = env.get("PGPOOL_SR_CHECK_PASSWORD", PGPOOL_BACKEND_PASSWORD);
const PGPOOL_SR_CHECK_DATABASE = env.get("PGPOOL_SR_CHECK_DATABASE", "postgres");
const PGPOOL_DELAY_THRESHOLD = env.get("PGPOOL_DELAY_THRESHOLD", "0");
const PGPOOL_DELAY_THRESHOLD_BY_TIME = env.get("PGPOOL_DELAY_THRESHOLD_BY_TIME", "0");
const PGPOOL_PREFER_LOWER_DELAY_STANDBY = env.get("PGPOOL_PREFER_LOWER_DELAY_STANDBY", "off");
const PGPOOL_LOG_STANDBY_DELAY = env.get("PGPOOL_LOG_STANDBY_DELAY", "if_over_threshold");
const PGPOOL_SEARCH_PRIMARY_NODE_TIMEOUT = env.get("PGPOOL_SEARCH_PRIMARY_NODE_TIMEOUT", "10");

// ---------------------------------------------------------------------------
// Failover (native pgpool hooks — pass-through only)
// ---------------------------------------------------------------------------
const PGPOOL_FAILOVER_COMMAND = env.get("PGPOOL_FAILOVER_COMMAND", "");
const PGPOOL_FOLLOW_MASTER_SCRIPT = env.get("PGPOOL_FOLLOW_MASTER_SCRIPT", "");

// ---------------------------------------------------------------------------
// Watchdog (High Availability)
// ---------------------------------------------------------------------------
const PGPOOL_ENABLE_WATCHDOG = env.bool("PGPOOL_ENABLE_WATCHDOG");
const PGPOOL_WD_HOSTNAME = env.get("PGPOOL_WD_HOSTNAME", "");
const PGPOOL_WD_PORT = env.get("PGPOOL_WD_PORT", "9000");
const PGPOOL_WD_AUTHENTICATION = env.get("PGPOOL_WD_AUTHENTICATION", "");
const PGPOOL_DELEGATE_IP = env.get("PGPOOL_DELEGATE_IP", "");
const PGPOOL_WD_LIFECHECK_METHOD = env.get("PGPOOL_WD_LIFECHECK_METHOD", "heartbeat");
const PGPOOL_WD_INTERVAL = env.get("PGPOOL_WD_INTERVAL", "10");
const PGPOOL_WD_PRIORITY = env.get("PGPOOL_WD_PRIORITY", "1");
const PGPOOL_WD_FAILOVER_TIMEOUT = env.get("PGPOOL_WD_FAILOVER_TIMEOUT", "15");

// ---------------------------------------------------------------------------
// Master / slave mode
// ---------------------------------------------------------------------------
const PGPOOL_MASTER_SLAVE_MODE = env.get("PGPOOL_MASTER_SLAVE_MODE", "on");
const PGPOOL_MASTER_SLAVE_SUB_MODE = env.get("PGPOOL_MASTER_SLAVE_SUB_MODE", "stream");

// ---------------------------------------------------------------------------
// Memory cache (query cache)
// ---------------------------------------------------------------------------
const PGPOOL_MEMORY_CACHE_MODE = env.bool("PGPOOL_MEMORY_CACHE_MODE");
const PGPOOL_MEMQCACHE_CACHE_BLOCKS = env.get("PGPOOL_MEMQCACHE_CACHE_BLOCKS", "8192");
const PGPOOL_MEMQCACHE_BLOCK_SIZE = env.get("PGPOOL_MEMQCACHE_BLOCK_SIZE", "1048576");
const PGPOOL_MEMQCACHE_MAXCACHE = env.get("PGPOOL_MEMQCACHE_MAXCACHE", "50");
const PGPOOL_MEMQCACHE_EXPIRE_TIME = env.get("PGPOOL_MEMQCACHE_EXPIRE_TIME", "10000");
const PGPOOL_MEMQCACHE_TOTAL_SIZE = env.get("PGPOOL_MEMQCACHE_TOTAL_SIZE", "1024");

// ---------------------------------------------------------------------------
// Connection pooling
// ---------------------------------------------------------------------------
const PGPOOL_CONNECTION_CACHE = env.get("PGPOOL_CONNECTION_CACHE", "on");
const PGPOOL_RESET_QUERY_LIST = env.get("PGPOOL_RESET_QUERY_LIST", "ABORT; DISCARD ALL");

// ---------------------------------------------------------------------------
// Query routing & validation
// ---------------------------------------------------------------------------
const PGPOOL_ENABLE_HINT_QUERY = env.get("PGPOOL_ENABLE_HINT_QUERY", "off");
const PGPOOL_VALIDATE_QUERY = env.get("PGPOOL_VALIDATE_QUERY", "off");
const PGPOOL_REPLICATION_CHECK = env.get("PGPOOL_REPLICATION_CHECK", "off");
const PGPOOL_AUTO_DB_REMOVE = env.get("PGPOOL_AUTO_DB_REMOVE", "off");
const PGPOOL_AUTOICACHE_REMOVE = env.get("PGPOOL_AUTOICACHE_REMOVE", "off");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE");

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const PGPOOL_CONF = PGPOOL_CONFIG_DIR + "/pgpool.conf";
const POOL_HBA_CONF = PGPOOL_CONFIG_DIR + "/pool_hba.conf";
const POOL_PASSWD_FILE = PGPOOL_CONFIG_DIR + "/" + PGPOOL_POOL_PASSWD;
const PGPOOL_PID_FILE = PGPOOL_RUN_DIR + "/pgpool.pid";

// pgpool ships these samples via `make install` under its prefix.
const PGPOOL_CONF_SAMPLE = "/usr/local/pgpool/etc/pgpool.conf.sample";
const POOL_HBA_CONF_SAMPLE = "/usr/local/pgpool/etc/pool_hba.conf.sample";

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const PGPOOL_READY_MAX_ATTEMPTS = env.int("PGPOOL_READY_MAX_ATTEMPTS", 30);

module.exports = {
  // directories
  PGPOOL_CONFIG_DIR,
  PGPOOL_LOG_DIR,
  PGPOOL_RUN_DIR,
  PGPOOL_USER,
  PGPOOL_GROUP,
  // core
  PGPOOL_PORT,
  PGPOOL_PCP_PORT,
  // tls
  PGPOOL_SSL,
  PGPOOL_SSL_KEY,
  PGPOOL_SSL_CERT,
  PGPOOL_SSL_SECURITY_MODE,
  // backends
  PGPOOL_BACKENDS,
  PGPOOL_BACKEND_WEIGHTS,
  PGPOOL_BACKEND_FLAGS,
  // patroni
  PGPOOL_PATRONI_ENDPOINTS,
  PGPOOL_PATRONI_TIMEOUT,
  // pool
  PGPOOL_NUM_INIT_CHILDREN,
  PGPOOL_MAX_POOL,
  PGPOOL_CHILD_LIFE_TIME,
  PGPOOL_CONNECTION_LIFE_TIME,
  PGPOOL_CHILD_MAX_CONNECTIONS,
  // lb
  PGPOOL_LOAD_BALANCE_MODE,
  PGPOOL_IGNORE_LEADING_WHITE_SPACE,
  // auth
  PGPOOL_ENABLE_POOL_HBA,
  PGPOOL_POOL_PASSWD,
  PGPOOL_BACKEND_USER,
  PGPOOL_BACKEND_PASSWORD,
  // health check
  PGPOOL_HEALTH_CHECK_TIMEOUT,
  PGPOOL_HEALTH_CHECK_PERIOD,
  PGPOOL_HEALTH_CHECK_USER,
  PGPOOL_HEALTH_CHECK_PASSWORD,
  PGPOOL_HEALTH_CHECK_DATABASE,
  PGPOOL_HEALTH_CHECK_MAX_RETRIES,
  PGPOOL_HEALTH_CHECK_RETRY_DELAY,
  PGPOOL_CONNECT_TIMEOUT,
  // pcp
  PGPOOL_PCP_TIMEOUT,
  PGPOOL_PCP_NUM_CHILDREN,
  // logging
  PGPOOL_LOG_MIN_MESSAGES,
  PGPOOL_LOG_HOSTNAME,
  // sr check
  PGPOOL_SR_CHECK_PERIOD,
  PGPOOL_SR_CHECK_USER,
  PGPOOL_SR_CHECK_PASSWORD,
  PGPOOL_SR_CHECK_DATABASE,
  PGPOOL_DELAY_THRESHOLD,
  PGPOOL_DELAY_THRESHOLD_BY_TIME,
  PGPOOL_PREFER_LOWER_DELAY_STANDBY,
  PGPOOL_LOG_STANDBY_DELAY,
  PGPOOL_SEARCH_PRIMARY_NODE_TIMEOUT,
  // failover
  PGPOOL_FAILOVER_COMMAND,
  PGPOOL_FOLLOW_MASTER_SCRIPT,
  // watchdog
  PGPOOL_ENABLE_WATCHDOG,
  PGPOOL_WD_HOSTNAME,
  PGPOOL_WD_PORT,
  PGPOOL_WD_AUTHENTICATION,
  PGPOOL_DELEGATE_IP,
  PGPOOL_WD_LIFECHECK_METHOD,
  PGPOOL_WD_INTERVAL,
  PGPOOL_WD_PRIORITY,
  PGPOOL_WD_FAILOVER_TIMEOUT,
  // master/slave
  PGPOOL_MASTER_SLAVE_MODE,
  PGPOOL_MASTER_SLAVE_SUB_MODE,
  // memory cache
  PGPOOL_MEMORY_CACHE_MODE,
  PGPOOL_MEMQCACHE_CACHE_BLOCKS,
  PGPOOL_MEMQCACHE_BLOCK_SIZE,
  PGPOOL_MEMQCACHE_MAXCACHE,
  PGPOOL_MEMQCACHE_EXPIRE_TIME,
  PGPOOL_MEMQCACHE_TOTAL_SIZE,
  // pooling
  PGPOOL_CONNECTION_CACHE,
  PGPOOL_RESET_QUERY_LIST,
  // routing
  PGPOOL_ENABLE_HINT_QUERY,
  PGPOOL_VALIDATE_QUERY,
  PGPOOL_REPLICATION_CHECK,
  PGPOOL_AUTO_DB_REMOVE,
  PGPOOL_AUTOICACHE_REMOVE,
  // misc
  SLEEP_MODE,
  // derived
  PGPOOL_CONF,
  POOL_HBA_CONF,
  POOL_PASSWD_FILE,
  PGPOOL_PID_FILE,
  PGPOOL_CONF_SAMPLE,
  POOL_HBA_CONF_SAMPLE,
  // readiness
  PGPOOL_READY_MAX_ATTEMPTS,
};
