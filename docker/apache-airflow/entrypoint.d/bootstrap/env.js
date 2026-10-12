// env.js — Apache Airflow environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const AIRFLOW_HOME = env.get("AIRFLOW_HOME", "/opt/airflow");
const AIRFLOW_DATA_DIR = env.get("AIRFLOW_DATA_DIR", "/opt/containers/data");
const AIRFLOW_CONFIG_DIR = env.get("AIRFLOW_CONFIG_DIR", "/opt/containers/config");
const AIRFLOW_LOG_DIR = env.get("AIRFLOW_LOG_DIR", "/opt/containers/logs");
const AIRFLOW_RUN_DIR = env.get("AIRFLOW_RUN_DIR", "/opt/containers/run");
const AIRFLOW_BACKUP_DIR = env.get("AIRFLOW_BACKUP_DIR", "/opt/containers/backup");
const AIRFLOW_DAGS_DIR = env.get("AIRFLOW_DAGS_DIR", AIRFLOW_DATA_DIR + "/dags");
const AIRFLOW_PLUGINS_DIR = env.get("AIRFLOW_PLUGINS_DIR", "/opt/airflow/plugins");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const AIRFLOW_USER = env.get("AIRFLOW_USER", "airflow");
const AIRFLOW_GROUP = env.get("AIRFLOW_GROUP", "airflow");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const AIRFLOW_PORT = env.get("AIRFLOW_PORT", env.get("AIRFLOW__WEBSERVER__WEB_SERVER_PORT", "8080"));
const AIRFLOW_HOST = env.get("AIRFLOW_HOST", "0.0.0.0");
const AIRFLOW_API_SERVER = env.get("AIRFLOW_API_SERVER", "/usr/local/bin/airflow");
// SQLite database lives on the data volume (matching the previous config).
const AIRFLOW_SQLALCHEMY_CONN = env.get(
	"AIRFLOW__DATABASE__SQL_ALCHEMY_CONN",
	env.get("AIRFLOW_SQLALCHEMY_CONN", "sqlite:////opt/containers/data/airflow.db"),
);

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("AIRFLOW_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const AIRFLOW_READY_MAX_ATTEMPTS = env.int("AIRFLOW_READY_MAX_ATTEMPTS", 60);
const AIRFLOW_READY_ATTEMPT_INTERVAL = env.int("AIRFLOW_READY_ATTEMPT_INTERVAL", 2);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const AIRFLOW_CONFIG_FILE = env.get("AIRFLOW_CONFIG", AIRFLOW_HOME + "/airflow.cfg");
// The bundled default config installed by forge from the repo's config dir.
const AIRFLOW_DEFAULT_CONFIG = "/opt/container/defaults/airflow.cfg";

module.exports = {
	AIRFLOW_HOME,
	AIRFLOW_DATA_DIR,
	AIRFLOW_CONFIG_DIR,
	AIRFLOW_LOG_DIR,
	AIRFLOW_RUN_DIR,
	AIRFLOW_BACKUP_DIR,
	AIRFLOW_DAGS_DIR,
	AIRFLOW_PLUGINS_DIR,
	AIRFLOW_USER,
	AIRFLOW_GROUP,
	AIRFLOW_PORT,
	AIRFLOW_HOST,
	AIRFLOW_API_SERVER,
	AIRFLOW_SQLALCHEMY_CONN,
	SLEEP_MODE,
	AIRFLOW_READY_MAX_ATTEMPTS,
	AIRFLOW_READY_ATTEMPT_INTERVAL,
	AIRFLOW_CONFIG_FILE,
	AIRFLOW_DEFAULT_CONFIG,
};
