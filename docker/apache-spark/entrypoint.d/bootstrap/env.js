// env.js — Apache Spark environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const SPARK_DATA_DIR = env.get("SPARK_DATA_DIR", "/opt/containers/data");
const SPARK_CONFIG_DIR = env.get("SPARK_CONFIG_DIR", "/opt/containers/config");
const SPARK_LOG_DIR = env.get("SPARK_LOG_DIR", "/opt/containers/logs");
const SPARK_RUN_DIR = env.get("SPARK_RUN_DIR", "/opt/containers/run");
const SPARK_BACKUP_DIR = env.get("SPARK_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const SPARK_USER = env.get("SPARK_USER", "spark");
const SPARK_GROUP = env.get("SPARK_GROUP", "spark");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const SPARK_HOME = env.get("SPARK_HOME", "/opt/spark");
const SPARK_MASTER_HOST = env.get("SPARK_MASTER_HOST", "localhost");
const SPARK_MASTER_PORT = env.get("SPARK_MASTER_PORT", "7077");
const SPARK_MASTER_WEBUI_PORT = env.get("SPARK_MASTER_WEBUI_PORT", "8080");
// The worker connects to the master URL; defaults to spark://<host>:<port>.
const SPARK_MASTER_URL = env.get("SPARK_MASTER_URL", "");
// Optional whitespace-separated extra args for the master / worker launchers.
const SPARK_MASTER_OPTS = env.get("SPARK_MASTER_OPTS", "");
const SPARK_WORKER_OPTS = env.get("SPARK_WORKER_OPTS", "");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("SPARK_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const SPARK_READY_MAX_ATTEMPTS = env.int("SPARK_READY_MAX_ATTEMPTS", 30);
const SPARK_READY_ATTEMPT_INTERVAL = env.int("SPARK_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// The bundled default config installed by forge, used to seed a missing config.
const SPARK_DEFAULT_CONFIG = "/opt/container/defaults/spark-defaults.conf";

// masterUrl — the spark:// URL the worker registers with.
function masterUrl() {
	if (SPARK_MASTER_URL) return SPARK_MASTER_URL;
	return "spark://" + SPARK_MASTER_HOST + ":" + SPARK_MASTER_PORT;
}

module.exports = {
	SPARK_DATA_DIR,
	SPARK_CONFIG_DIR,
	SPARK_LOG_DIR,
	SPARK_RUN_DIR,
	SPARK_BACKUP_DIR,
	SPARK_USER,
	SPARK_GROUP,
	SPARK_HOME,
	SPARK_MASTER_HOST,
	SPARK_MASTER_PORT,
	SPARK_MASTER_WEBUI_PORT,
	SPARK_MASTER_URL,
	SPARK_MASTER_OPTS,
	SPARK_WORKER_OPTS,
	SLEEP_MODE,
	SPARK_READY_MAX_ATTEMPTS,
	SPARK_READY_ATTEMPT_INTERVAL,
	SPARK_DEFAULT_CONFIG,
	masterUrl,
};
