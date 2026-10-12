// env.js — Grafana environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>). The GF_*
// names match Grafana's own variables so existing deployments keep working.
// ---------------------------------------------------------------------------
const GRAFANA_HOME = env.get("GF_PATHS_HOME", "/usr/share/grafana");
const GRAFANA_DATA_DIR = env.get("GF_PATHS_DATA", "/opt/containers/data");
const GRAFANA_LOG_DIR = env.get("GF_PATHS_LOGS", "/opt/containers/logs");
const GRAFANA_CONFIG_DIR = env.get("GRAFANA_CONFIG_DIR", "/opt/containers/config");
const GRAFANA_RUN_DIR = env.get("GRAFANA_RUN_DIR", "/opt/containers/run");
const GRAFANA_BACKUP_DIR = env.get("GRAFANA_BACKUP_DIR", "/opt/containers/backup");

const GRAFANA_CONFIG_FILE = env.get("GF_PATHS_CONFIG", GRAFANA_CONFIG_DIR + "/grafana.ini");
const GRAFANA_PLUGINS_DIR = env.get("GF_PATHS_PLUGINS", "/var/lib/grafana/plugins");
const GRAFANA_PROVISIONING_DIR = env.get("GF_PATHS_PROVISIONING", GRAFANA_CONFIG_DIR + "/provisioning");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const GRAFANA_USER = env.get("GRAFANA_USER", "grafana");
const GRAFANA_GROUP = env.get("GRAFANA_GROUP", "grafana");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
// Grafana reads GF_SERVER_HTTP_PORT from the environment natively; GRAFANA_PORT
// is the container-friendly override used for the readiness/health probes.
const GRAFANA_PORT = env.get("GRAFANA_PORT", env.get("GF_SERVER_HTTP_PORT", "3000"));
const GRAFANA_PACKAGING = env.get("GRAFANA_PACKAGING", "docker");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
// SLEEP_MODE is the cross-container convention; GRAFANA_SLEEP_MODE is kept as a
// backwards-compatible alias.
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("GRAFANA_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const GRAFANA_READY_MAX_ATTEMPTS = env.int("GRAFANA_READY_MAX_ATTEMPTS", 30);
const GRAFANA_READY_ATTEMPT_INTERVAL = env.int("GRAFANA_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// The bundled default config installed by forge, used to seed a missing config
// file so a bare docker run works out of the box.
const GRAFANA_DEFAULT_CONFIG = GRAFANA_HOME + "/conf/defaults.ini";

module.exports = {
	// directories
	GRAFANA_HOME,
	GRAFANA_DATA_DIR,
	GRAFANA_LOG_DIR,
	GRAFANA_CONFIG_DIR,
	GRAFANA_RUN_DIR,
	GRAFANA_BACKUP_DIR,
	GRAFANA_CONFIG_FILE,
	GRAFANA_PLUGINS_DIR,
	GRAFANA_PROVISIONING_DIR,
	// identity
	GRAFANA_USER,
	GRAFANA_GROUP,
	// core
	GRAFANA_PORT,
	GRAFANA_PACKAGING,
	// misc
	SLEEP_MODE,
	// readiness
	GRAFANA_READY_MAX_ATTEMPTS,
	GRAFANA_READY_ATTEMPT_INTERVAL,
	// derived
	GRAFANA_DEFAULT_CONFIG,
};
