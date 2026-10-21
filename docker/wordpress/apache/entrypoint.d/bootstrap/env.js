// env.js — WordPress environment configuration.
//
// Single source of truth for every environment-driven setting. Every name
// exported here is consumed by at least one bootstrap module. Booleans use
// env.bool() so they arrive as real JS booleans (the string "false" is truthy
// and would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const DATA_DIR = env.get("WORDPRESS_DATA_DIR", "/opt/containers/data");
const CONFIG_DIR = env.get("WORDPRESS_CONFIG_DIR", "/opt/containers/config");
const LOG_DIR = env.get("WORDPRESS_LOG_DIR", "/opt/containers/logs");
const RUN_DIR = env.get("WORDPRESS_RUN_DIR", "/opt/containers/run");

// The legacy /content path is kept as a symlink to DATA_DIR for backwards
// compatibility with existing volumes that mounted /content.
const CONTENT_DIR = env.get("WORDPRESS_CONTENT_DIR", "/content");

// ---------------------------------------------------------------------------
// Identity & application paths
// ---------------------------------------------------------------------------
const WORDPRESS_USER = env.get("WORDPRESS_USER", "www-data");
const WORDPRESS_GROUP = env.get("WORDPRESS_GROUP", "www-data");
const WORDPRESS_ROOT = env.get("WORDPRESS_ROOT", "/var/www/html");
const WORDPRESS_CONFIG_FILE = env.get("WORDPRESS_CONFIG_FILE", WORDPRESS_ROOT + "/wp-config.php");
const WORDPRESS_CONTENT_ROOT = env.get("WORDPRESS_CONTENT_ROOT", WORDPRESS_ROOT + "/wp-content");
const APACHE_ROOT = env.get("APACHE_ROOT", "/usr/local/apache2");
const APACHE_CONF = env.get("APACHE_CONF", APACHE_ROOT + "/conf/httpd.conf");
const APACHE_STATUS_CONF = env.get("APACHE_STATUS_CONF", APACHE_ROOT + "/conf/extra/httpd-status.conf");
const APACHE_MPM_CONF = env.get("APACHE_MPM_CONF", APACHE_ROOT + "/conf/extra/httpd-mpm.conf");
// A container-owned security include. Kept separate from httpd.conf so the
// hardening directives live in one fully-reset file (idempotent across
// restarts) instead of being appended after a config that Apache may have
// relocated (the php_module LoadModule/AddType block moves to EOF).
const APACHE_SECURITY_CONF = env.get("APACHE_SECURITY_CONF", APACHE_ROOT + "/conf/extra/httpd-security.conf");
// A container-owned performance include (compression + browser caching). Kept
// separate from httpd.conf and from the security include for the same reason:
// deterministic ordering and idempotent rewrites.
const APACHE_PERFORMANCE_CONF = env.get("APACHE_PERFORMANCE_CONF", APACHE_ROOT + "/conf/extra/httpd-performance.conf");
const APACHE_HTPASSWD = env.get("APACHE_BIN", APACHE_ROOT + "/bin/httpd");
const PHP_INI = env.get("PHP_INI", "/usr/local/lib/php.ini");
// PHP_DIR holds the shipped PHP fragments (https.php, loopback.php) that the
// entrypoint includes into wp-config.php by path, so no PHP is written as a JS
// string.
const PHP_DIR = env.get("WORDPRESS_PHP_DIR", "/opt/container/config/php");

// ---------------------------------------------------------------------------
// Database (required)
// ---------------------------------------------------------------------------
const WORDPRESS_DB_NAME = env.get("WORDPRESS_DB_NAME", "");
const WORDPRESS_DB_USER = env.get("WORDPRESS_DB_USER", "");
const WORDPRESS_DB_PASSWORD = env.get("WORDPRESS_DB_PASSWORD", "");
const WORDPRESS_DB_HOST = env.get("WORDPRESS_DB_HOST", "");
const WORDPRESS_DB_CHARSET = env.get("WORDPRESS_DB_CHARSET", "");
const WORDPRESS_DB_COLLATE = env.get("WORDPRESS_DB_COLLATE", "");

// ---------------------------------------------------------------------------
// Mode toggles
// ---------------------------------------------------------------------------
const IS_STATELESS = env.bool("IS_STATELESS");
const IS_HTTPS = env.bool("IS_HTTPS");
const IS_PROTECT_XMLRPC = env.bool("IS_PROTECT_XMLRPC");
const IS_PROTECT_WPCONFIG = env.bool("IS_PROTECT_WPCONFIG");
const CUSTOM_TABLE_PREFIX = env.get("CUSTOM_TABLE_PREFIX", "");
const SKIP_PERMISSIONS = env.bool("SKIP_PERMISSIONS");

// ---------------------------------------------------------------------------
// Security baseline (hardening). See docs/wordpress/hardening.md.
//
// IS_SECURITY_BASELINE is the umbrella: when true it turns on the safe, no-
// downside hardening set below. Each setting may also be toggled on its own,
// independently of the umbrella. All default to the umbrella's value (off
// unless the umbrella is set), so enabling the baseline enables everything and
// granular flags still work alone.
// ---------------------------------------------------------------------------
const IS_SECURITY_BASELINE = env.bool("IS_SECURITY_BASELINE");
const IS_HIDE_SERVER_INFO = env.bool("IS_HIDE_SERVER_INFO", IS_SECURITY_BASELINE);
const IS_DISABLE_DIRLIST = env.bool("IS_DISABLE_DIRLIST", IS_SECURITY_BASELINE);
const IS_DISABLE_TRACE = env.bool("IS_DISABLE_TRACE", IS_SECURITY_BASELINE);
const IS_SECURITY_HEADERS = env.bool("IS_SECURITY_HEADERS", IS_SECURITY_BASELINE);
const IS_BLOCK_SENSITIVE_FILES = env.bool("IS_BLOCK_SENSITIVE_FILES", IS_SECURITY_BASELINE);
const IS_BLOCK_PHP_IN_UPLOADS = env.bool("IS_BLOCK_PHP_IN_UPLOADS", IS_SECURITY_BASELINE);
const IS_SLOWLORIS_PROTECT = env.bool("IS_SLOWLORIS_PROTECT", IS_SECURITY_BASELINE);
const IS_PROTECT_WPLOGIN = env.bool("IS_PROTECT_WPLOGIN");
// IS_HSTS is off by default even under the umbrella: a wrong HSTS header can
// make a domain unreachable, so it is always an explicit opt-in.
const IS_HSTS = env.bool("IS_HSTS");

// Explicit values. Empty means "use the built-in default".
const APACHE_REQTIMEOUT = env.get("APACHE_REQTIMEOUT", "");
const APACHE_RATE_LIMIT = env.get("APACHE_RATE_LIMIT", "");
const APACHE_MAX_KEEPALIVE_REQUESTS = env.get("APACHE_MAX_KEEPALIVE_REQUESTS", "");
const TRUSTED_PROXY_IPS = env.get("TRUSTED_PROXY_IPS", "");
const WP_LOGIN_ALLOW_IPS = env.get("WP_LOGIN_ALLOW_IPS", "");

// ---------------------------------------------------------------------------
// Performance (compression + browser caching). See docs/wordpress/performance.md.
//
// Off by default, like the security baseline, so existing deployments are
// unaffected. IS_COMPRESSION turns on gzip (mod_deflate) and, when APACHE_BROTLI
// is also set, Brotli (mod_brotli) as the preferred encoding. IS_EXPIRES_CACHING
// turns on mod_expires with long lifetimes for versioned static assets and a
// revalidating lifetime for HTML.
// ---------------------------------------------------------------------------
const IS_COMPRESSION = env.bool("IS_COMPRESSION");
const IS_EXPIRES_CACHING = env.bool("IS_EXPIRES_CACHING");
// Brotli is opt-in: it compresses better than gzip but costs more CPU.
const APACHE_BROTLI = env.bool("APACHE_BROTLI");
const APACHE_BROTLI_QUALITY = env.get("APACHE_BROTLI_QUALITY", "5");
// Comma/space separated MIME types to compress; empty means the built-in list.
const APACHE_COMPRESS_TYPES = env.get("APACHE_COMPRESS_TYPES", "");
// mod_expires lifetimes. Accepts Apache syntax, e.g. "access plus 1 year".
const APACHE_EXPIRES_ASSETS = env.get("APACHE_EXPIRES_ASSETS", "");
const APACHE_EXPIRES_HTML = env.get("APACHE_EXPIRES_HTML", "");

// ---------------------------------------------------------------------------
// PHP limits (php.ini)
// ---------------------------------------------------------------------------
const PHP_MEMORY_LIMIT = env.get("PHP_MEMORY_LIMIT", "");
const PHP_UPLOAD_MAX_FILESIZE = env.get("PHP_UPLOAD_MAX_FILESIZE", "");
const PHP_POST_MAX_SIZE = env.get("PHP_POST_MAX_SIZE", "");
const PHP_MAX_EXECUTION_TIME = env.get("PHP_MAX_EXECUTION_TIME", "");
const PHP_MAX_INPUT_TIME = env.get("PHP_MAX_INPUT_TIME", "");
const PHP_OPCACHE_ENABLE = env.bool("PHP_OPCACHE_ENABLE", true);
const PHP_OPCACHE_MEMORY = env.get("PHP_OPCACHE_MEMORY", "");
const PHP_OPCACHE_MAX_ACCELERATED_FILES = env.get("PHP_OPCACHE_MAX_ACCELERATED_FILES", "");

// ---------------------------------------------------------------------------
// Apache MPM
// ---------------------------------------------------------------------------
const APACHE_MPM = env.get("APACHE_MPM", "event");
const APACHE_LOW_MEMORY_MODE = env.bool("APACHE_LOW_MEMORY_MODE");
const APACHE_INCLUDE_CONFIG_MPM = env.bool("APACHE_INCLUDE_CONFIG_MPM");
const APACHE_CUSTOM_MPM_PREFORK = env.bool("APACHE_CUSTOM_MPM_PREFORK");
const APACHE_CUSTOM_MPM_EVENT = env.bool("APACHE_CUSTOM_MPM_EVENT");
const APACHE_CUSTOM_MPM_WORKER = env.bool("APACHE_CUSTOM_MPM_WORKER");

// Prefork tuning (defaults chosen per the bash low-memory vs normal branches).
const APACHE_MPM_PREFORK_START_SERVERS = env.get("APACHE_MPM_PREFORK_START_SERVERS", "");
const APACHE_MPM_PREFORK_MIN_SPARE_SERVERS = env.get("APACHE_MPM_PREFORK_MIN_SPARE_SERVERS", "");
const APACHE_MPM_PREFORK_MAX_SPARE_SERVERS = env.get("APACHE_MPM_PREFORK_MAX_SPARE_SERVERS", "");
const APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS = env.get("APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS", "");
const APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD = env.get("APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD", "");

// Event tuning.
const APACHE_MPM_EVENT_START_SERVERS = env.get("APACHE_MPM_EVENT_START_SERVERS", "");
const APACHE_MPM_EVENT_MIN_SPARE_THREADS = env.get("APACHE_MPM_EVENT_MIN_SPARE_THREADS", "");
const APACHE_MPM_EVENT_MAX_SPARE_THREADS = env.get("APACHE_MPM_EVENT_MAX_SPARE_THREADS", "");
const APACHE_MPM_EVENT_THREADS_PER_CHILD = env.get("APACHE_MPM_EVENT_THREADS_PER_CHILD", "");
const APACHE_MPM_EVENT_MAX_REQUEST_WORKERS = env.get("APACHE_MPM_EVENT_MAX_REQUEST_WORKERS", "");
const APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD = env.get("APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD", "");

// Worker tuning.
const APACHE_MPM_WORKER_START_SERVERS = env.get("APACHE_MPM_WORKER_START_SERVERS", "");
const APACHE_MPM_WORKER_MIN_SPARE_THREADS = env.get("APACHE_MPM_WORKER_MIN_SPARE_THREADS", "");
const APACHE_MPM_WORKER_MAX_SPARE_THREADS = env.get("APACHE_MPM_WORKER_MAX_SPARE_THREADS", "");
const APACHE_MPM_WORKER_THREADS_PER_CHILD = env.get("APACHE_MPM_WORKER_THREADS_PER_CHILD", "");
const APACHE_MPM_WORKER_MAX_REQUEST_WORKERS = env.get("APACHE_MPM_WORKER_MAX_REQUEST_WORKERS", "");
const APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD = env.get("APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD", "");

// ---------------------------------------------------------------------------
// Apache status / exporter
// ---------------------------------------------------------------------------
const APACHE_PORT = env.get("APACHE_PORT", "80");
const APACHE_STATUS = env.bool("APACHE_STATUS");
const APACHE_STATUS_PUBLIC = env.bool("APACHE_STATUS_PUBLIC");
const APACHE_EXPORTER = env.bool("APACHE_EXPORTER");
const APACHE_EXPORTER_PORT = env.get("APACHE_EXPORTER_PORT", "9117");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE");

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const APACHE_READY_MAX_ATTEMPTS = env.int("APACHE_READY_MAX_ATTEMPTS", 30);
const APACHE_READY_ATTEMPT_INTERVAL = env.int("APACHE_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// WordPress's wp-content lives on the persistent data volume; WordPress
// itself is the immutable image content.
const DATA_WP_CONTENT = DATA_DIR + "/wp-content";
const DATA_UPLOADS = DATA_WP_CONTENT + "/uploads";
const CONTENT_STATELESS_DIR = CONTENT_DIR + "/stateless";
const WORDPRESS_SAMPLE_CONFIG = WORDPRESS_ROOT + "/wp-config-sample.php";

// ---------------------------------------------------------------------------
// Apache process identity / logging. httpd runs as root so it can bind port 80
// and then drop to www-data for its worker children (the httpd.conf User/Group
// directives); empty means "inherit" for ezx, i.e. stay root.
// ---------------------------------------------------------------------------
const APACHE_USER = env.get("APACHE_RUN_USER", "root");
const APACHE_GROUP = env.get("APACHE_RUN_GROUP", "root");
const APACHE_LOG_DIR = LOG_DIR + "/apache";

module.exports = {
  // directories
  DATA_DIR,
  CONFIG_DIR,
  LOG_DIR,
  RUN_DIR,
  CONTENT_DIR,
  // identity & paths
  WORDPRESS_USER,
  WORDPRESS_GROUP,
  WORDPRESS_ROOT,
  WORDPRESS_CONFIG_FILE,
  WORDPRESS_CONTENT_ROOT,
  APACHE_ROOT,
  APACHE_CONF,
  APACHE_STATUS_CONF,
  APACHE_MPM_CONF,
  APACHE_SECURITY_CONF,
  APACHE_PERFORMANCE_CONF,
  APACHE_HTPASSWD,
  PHP_INI,
  PHP_DIR,
  // database
  WORDPRESS_DB_NAME,
  WORDPRESS_DB_USER,
  WORDPRESS_DB_PASSWORD,
  WORDPRESS_DB_HOST,
  WORDPRESS_DB_CHARSET,
  WORDPRESS_DB_COLLATE,
  // mode toggles
  IS_STATELESS,
  IS_HTTPS,
  IS_PROTECT_XMLRPC,
  IS_PROTECT_WPCONFIG,
  // security baseline
  IS_SECURITY_BASELINE,
  IS_HIDE_SERVER_INFO,
  IS_DISABLE_DIRLIST,
  IS_DISABLE_TRACE,
  IS_SECURITY_HEADERS,
  IS_BLOCK_SENSITIVE_FILES,
  IS_BLOCK_PHP_IN_UPLOADS,
  IS_SLOWLORIS_PROTECT,
  IS_PROTECT_WPLOGIN,
  IS_HSTS,
  APACHE_REQTIMEOUT,
  APACHE_RATE_LIMIT,
  APACHE_MAX_KEEPALIVE_REQUESTS,
  TRUSTED_PROXY_IPS,
  WP_LOGIN_ALLOW_IPS,
  // performance
  IS_COMPRESSION,
  IS_EXPIRES_CACHING,
  APACHE_BROTLI,
  APACHE_BROTLI_QUALITY,
  APACHE_COMPRESS_TYPES,
  APACHE_EXPIRES_ASSETS,
  APACHE_EXPIRES_HTML,
  CUSTOM_TABLE_PREFIX,
  SKIP_PERMISSIONS,
  // php limits
  PHP_MEMORY_LIMIT,
  PHP_UPLOAD_MAX_FILESIZE,
  PHP_POST_MAX_SIZE,
  PHP_MAX_EXECUTION_TIME,
  PHP_MAX_INPUT_TIME,
  PHP_OPCACHE_ENABLE,
  PHP_OPCACHE_MEMORY,
  PHP_OPCACHE_MAX_ACCELERATED_FILES,
  // apache mpm
  APACHE_MPM,
  APACHE_LOW_MEMORY_MODE,
  APACHE_INCLUDE_CONFIG_MPM,
  APACHE_CUSTOM_MPM_PREFORK,
  APACHE_CUSTOM_MPM_EVENT,
  APACHE_CUSTOM_MPM_WORKER,
  APACHE_MPM_PREFORK_START_SERVERS,
  APACHE_MPM_PREFORK_MIN_SPARE_SERVERS,
  APACHE_MPM_PREFORK_MAX_SPARE_SERVERS,
  APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS,
  APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD,
  APACHE_MPM_EVENT_START_SERVERS,
  APACHE_MPM_EVENT_MIN_SPARE_THREADS,
  APACHE_MPM_EVENT_MAX_SPARE_THREADS,
  APACHE_MPM_EVENT_THREADS_PER_CHILD,
  APACHE_MPM_EVENT_MAX_REQUEST_WORKERS,
  APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD,
  APACHE_MPM_WORKER_START_SERVERS,
  APACHE_MPM_WORKER_MIN_SPARE_THREADS,
  APACHE_MPM_WORKER_MAX_SPARE_THREADS,
  APACHE_MPM_WORKER_THREADS_PER_CHILD,
  APACHE_MPM_WORKER_MAX_REQUEST_WORKERS,
  APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD,
  // status / exporter
  APACHE_PORT,
  APACHE_STATUS,
  APACHE_STATUS_PUBLIC,
  APACHE_EXPORTER,
  APACHE_EXPORTER_PORT,
  // misc
  SLEEP_MODE,
  // apache runtime aliases (consumed by runtime.js)
  APACHE_USER,
  APACHE_GROUP,
  APACHE_LOG_DIR,
  // readiness
  APACHE_READY_MAX_ATTEMPTS,
  APACHE_READY_ATTEMPT_INTERVAL,
  // derived
  DATA_WP_CONTENT,
  DATA_UPLOADS,
  CONTENT_STATELESS_DIR,
  WORDPRESS_SAMPLE_CONFIG,
};
