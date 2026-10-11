// env.js — Prometheus environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature flag).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const PROMETHEUS_DATA_DIR = env.get("PROMETHEUS_DATA_DIR", "/opt/containers/data");
const PROMETHEUS_CONFIG_DIR = env.get("PROMETHEUS_CONFIG_DIR", "/opt/containers/config");
const PROMETHEUS_LOG_DIR = env.get("PROMETHEUS_LOG_DIR", "/opt/containers/logs");
const PROMETHEUS_RUN_DIR = env.get("PROMETHEUS_RUN_DIR", "/opt/containers/run");
const PROMETHEUS_BACKUP_DIR = env.get("PROMETHEUS_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const PROMETHEUS_USER = env.get("PROMETHEUS_USER", "prometheus");
const PROMETHEUS_GROUP = env.get("PROMETHEUS_GROUP", "prometheus");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const PROMETHEUS_PORT = env.get("PROMETHEUS_PORT", "9090");
const PROMETHEUS_CONFIG_FILE = env.get("PROMETHEUS_CONFIG_FILE", PROMETHEUS_CONFIG_DIR + "/prometheus.yml");
// TLS / auth for the web endpoint.
const PROMETHEUS_WEB_CONFIG_FILE = env.get("PROMETHEUS_WEB_CONFIG_FILE", "");

// ---------------------------------------------------------------------------
// Storage / TSDB
// ---------------------------------------------------------------------------
const PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION = env.get(
	"PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION",
	"",
);
const PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION = env.get(
	"PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION",
	"",
);
const PROMETHEUS_STORAGE_TSDB_RETENTION_TIME = env.get("PROMETHEUS_STORAGE_TSDB_RETENTION_TIME", "");
const PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE = env.get("PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE", "");

// ---------------------------------------------------------------------------
// Web feature toggles
// ---------------------------------------------------------------------------
const PROMETHEUS_ENABLE_WEB_LIFECYCLE = env.bool("PROMETHEUS_ENABLE_WEB_LIFECYCLE");
const PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER = env.bool("PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER");
const PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER = env.bool("PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER");

// ---------------------------------------------------------------------------
// --enable-feature toggles. Each entry maps the env var to the feature name
// Prometheus expects. Keeping the mapping in one table means runtime.js can
// emit the flags declaratively and the list stays reviewable in one place.
// ---------------------------------------------------------------------------
const PROMETHEUS_FEATURES = [
	{ env: "PROMETHEUS_ENABLE_NATIVE_HISTOGRAM", feature: "native-histograms" },
	{ env: "PROMETHEUS_ENABLE_EXEMPLAR_STORAGE", feature: "exemplar-storage" },
	{ env: "PROMETHEUS_ENABLE_MEMORY_SNAPSHOT_ON_SHUTDOWN", feature: "memory-snapshot-on-shutdown" },
	{ env: "PROMETHEUS_ENABLE_EXTRA_SCRAPE_METRICS", feature: "extra-scrape-metrics" },
	{ env: "PROMETHEUS_ENABLE_PER_STEP_STATS", feature: "promql-per-step-stats" },
	{ env: "PROMETHEUS_ENABLE_PROMQL_FUNCTIONS", feature: "promql-experimental-functions" },
	{ env: "PROMETHEUS_ENABLE_CREATED_TIMESTAMPS_ZERO_INJECTION", feature: "created-timestamp-zero-ingestion" },
	{ env: "PROMETHEUS_ENABLE_CONCURRENT_RULE_EVAL", feature: "concurrent-rule-eval" },
	{ env: "PROMETHEUS_ENABLE_OLD_UI", feature: "old-ui" },
	{ env: "PROMETHEUS_ENABLE_METADATA_WAL_RECORDS", feature: "metadata-wal-records" },
	{ env: "PROMETHEUS_ENABLE_DELAYED_COMPACTION", feature: "delayed-compaction" },
	{ env: "PROMETHEUS_ENABLE_PROMQL_DELAYED_NAME_REMOVAL", feature: "promql-delayed-name-removal" },
	{ env: "PROMETHEUS_ENABLE_AUTO_RELOAD_CONFIG", feature: "auto-reload-config" },
	{ env: "PROMETHEUS_ENABLE_OLTP_DELTA_CONVERSION", feature: "oltp-delta-conversion" },
	{ env: "PROMETHEUS_ENABLE_PROMQL_DURATION_EXPR", feature: "promql-duration-expr" },
	{ env: "PROMETHEUS_ENABLE_OLTP_NATIVE_DELTA", feature: "otlp-native-delta-ingestion" },
	{ env: "PROMETHEUS_ENABLE_TYPE_AND_UNIT_LABELS", feature: "type-and-unit-labels" },
	{ env: "PROMETHEUS_ENABLE_USE_UNCACHED_IO", feature: "use-uncached-io" },
].filter((f) => env.bool(f.env));

// ---------------------------------------------------------------------------
// Logging / lifecycle
// ---------------------------------------------------------------------------
const LOG_LEVEL = env.get("LOG_LEVEL", "info");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
// SLEEP_MODE is the cross-container convention; PROMETHEUS_SLEEP_MODE is kept as
// a backwards-compatible alias.
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("PROMETHEUS_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const PROMETHEUS_READY_MAX_ATTEMPTS = env.int("PROMETHEUS_READY_MAX_ATTEMPTS", 30);
const PROMETHEUS_READY_ATTEMPT_INTERVAL = env.int("PROMETHEUS_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// The bundled default config installed by forge, used to seed a missing config
// file so a bare `docker run` works out of the box.
const PROMETHEUS_DEFAULT_CONFIG = "/opt/container/prometheus.yml.default";

module.exports = {
	// directories
	PROMETHEUS_DATA_DIR,
	PROMETHEUS_CONFIG_DIR,
	PROMETHEUS_LOG_DIR,
	PROMETHEUS_RUN_DIR,
	PROMETHEUS_BACKUP_DIR,
	// identity
	PROMETHEUS_USER,
	PROMETHEUS_GROUP,
	// core
	PROMETHEUS_PORT,
	PROMETHEUS_CONFIG_FILE,
	PROMETHEUS_WEB_CONFIG_FILE,
	// storage
	PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION,
	PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION,
	PROMETHEUS_STORAGE_TSDB_RETENTION_TIME,
	PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE,
	// web toggles
	PROMETHEUS_ENABLE_WEB_LIFECYCLE,
	PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER,
	PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER,
	// feature flags
	PROMETHEUS_FEATURES,
	// logging / lifecycle
	LOG_LEVEL,
	SLEEP_MODE,
	// readiness
	PROMETHEUS_READY_MAX_ATTEMPTS,
	PROMETHEUS_READY_ATTEMPT_INTERVAL,
	// derived
	PROMETHEUS_DEFAULT_CONFIG,
};
