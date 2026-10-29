// env.js — Grafana Mimir environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const GRAFANA_MIMIR_CONFIG_DIR = env.get("GRAFANA_MIMIR_CONFIG_DIR", "/opt/containers/config");
const GRAFANA_MIMIR_DATA_DIR = env.get("GRAFANA_MIMIR_DATA_DIR", "/opt/containers/data");
const GRAFANA_MIMIR_LOG_DIR = env.get("GRAFANA_MIMIR_LOG_DIR", "/opt/containers/logs");
const GRAFANA_MIMIR_RUN_DIR = env.get("GRAFANA_MIMIR_RUN_DIR", "/opt/containers/run");
const GRAFANA_MIMIR_BACKUP_DIR = env.get("GRAFANA_MIMIR_BACKUP_DIR", "/opt/containers/backup");

const GRAFANA_MIMIR_CONFIG = env.get("GRAFANA_MIMIR_CONFIG", GRAFANA_MIMIR_CONFIG_DIR + "/mimir.yaml");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const GRAFANA_MIMIR_USER = env.get("GRAFANA_MIMIR_USER", "mimir");
const GRAFANA_MIMIR_GROUP = env.get("GRAFANA_MIMIR_GROUP", "mimir");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
// MIMIR_TARGET selects the component set: all, alertmanager, overrides-exporter,
// distributor, ingester, querier, query-frontend, query-scheduler, compactor,
// store-gateway, ruler.
const MIMIR_TARGET = env.get("MIMIR_TARGET", "all");
const MIMIR_STORAGE_PREFIX = env.get("MIMIR_STORAGE_PREFIX", "blocks");
// Mimir refuses a tsdb dir that overlaps the bucket-store sync dir, so each
// gets its own subdirectory of the data volume instead of the volume itself.
const MIMIR_TSDB_DIR = env.get("MIMIR_TSDB_DIR", GRAFANA_MIMIR_DATA_DIR + "/tsdb");
const MIMIR_ACTIVITY_FILE = env.get("MIMIR_ACTIVITY_FILE", GRAFANA_MIMIR_DATA_DIR + "/metrics-activity.log");
// Mimir defaults these to ./tsdb-sync, ./data-compactor and ./data-ruler, all
// relative to a working directory the mimir user cannot write.
const MIMIR_SYNC_DIR = env.get("MIMIR_SYNC_DIR", GRAFANA_MIMIR_DATA_DIR + "/tsdb-sync");
const MIMIR_COMPACTOR_DIR = env.get("MIMIR_COMPACTOR_DIR", GRAFANA_MIMIR_DATA_DIR + "/compactor");
const MIMIR_RULER_DIR = env.get("MIMIR_RULER_DIR", GRAFANA_MIMIR_DATA_DIR + "/ruler");
// Comma-separated list of ingester addresses (enables clustering when set).
const MIMIR_MEMBER_LIST = env.get("MIMIR_MEMBER_LIST", "");
const GRAFANA_MIMIR_EXTRA_ARGS = env.get("GRAFANA_MIMIR_EXTRA_ARGS", "");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("GRAFANA_MIMIR_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const GRAFANA_MIMIR_READY_MAX_ATTEMPTS = env.int("GRAFANA_MIMIR_READY_MAX_ATTEMPTS", 30);
const GRAFANA_MIMIR_READY_ATTEMPT_INTERVAL = env.int("GRAFANA_MIMIR_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
// Total number of ingesters from MIMIR_MEMBER_LIST (1 when unset); used as the
// default replication factor, matching the bash entrypoint.
function memberCount() {
	if (!MIMIR_MEMBER_LIST) return 1;
	return String(MIMIR_MEMBER_LIST)
		.split(",")
		.map((m) => m.trim())
		.filter(Boolean).length;
}

// The replication factor is MIMIR_INGESTER_REPLICATION_FACTOR, defaulting to
// the member count. (The bash entrypoint also exported the misspelled
// MIMIR_INGERSTER_REPLICATION_FACTOR; MIMIR_INGESTER_REPLICATION_FACTOR is the
// documented spelling.)
const MIMIR_INGESTER_REPLICATION_FACTOR = env.int(
	"MIMIR_INGESTER_REPLICATION_FACTOR",
	memberCount(),
);

// Binary path (kept configurable, matching the bash entrypoint).
const MIMIR_BIN = env.get("GRAFANA_MIMIR_BIN", "/usr/share/grafana/mimir");
// Port Mimir serves its HTTP API on (default 8080, Mimir's own default).
const MIMIR_HTTP_PORT = env.get("MIMIR_HTTP_PORT", "8080");

module.exports = {
	GRAFANA_MIMIR_CONFIG_DIR,
	GRAFANA_MIMIR_DATA_DIR,
	GRAFANA_MIMIR_LOG_DIR,
	GRAFANA_MIMIR_RUN_DIR,
	GRAFANA_MIMIR_BACKUP_DIR,
	GRAFANA_MIMIR_CONFIG,
	GRAFANA_MIMIR_USER,
	GRAFANA_MIMIR_GROUP,
	MIMIR_TARGET,
	MIMIR_STORAGE_PREFIX,
	MIMIR_TSDB_DIR,
	MIMIR_ACTIVITY_FILE,
	MIMIR_SYNC_DIR,
	MIMIR_COMPACTOR_DIR,
	MIMIR_RULER_DIR,
	MIMIR_MEMBER_LIST,
	GRAFANA_MIMIR_EXTRA_ARGS,
	SLEEP_MODE,
	GRAFANA_MIMIR_READY_MAX_ATTEMPTS,
	GRAFANA_MIMIR_READY_ATTEMPT_INTERVAL,
	MIMIR_INGESTER_REPLICATION_FACTOR,
	MIMIR_BIN,
	MIMIR_HTTP_PORT,
	memberCount,
};
