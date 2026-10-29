// env.js — Grafana Alloy environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const GRAFANA_ALLOY_CONFIG_DIR = env.get("GRAFANA_ALLOY_CONFIG_DIR", "/opt/containers/config");
const GRAFANA_ALLOY_DATA_DIR = env.get("GRAFANA_ALLOY_DATA_DIR", "/opt/containers/data");
const GRAFANA_ALLOY_LOG_DIR = env.get("GRAFANA_ALLOY_LOG_DIR", "/opt/containers/logs");
const GRAFANA_ALLOY_RUN_DIR = env.get("GRAFANA_ALLOY_RUN_DIR", "/opt/containers/run");
const GRAFANA_ALLOY_BACKUP_DIR = env.get("GRAFANA_ALLOY_BACKUP_DIR", "/opt/containers/backup");

const GRAFANA_ALLOY_CONFIG = env.get("GRAFANA_ALLOY_CONFIG", GRAFANA_ALLOY_CONFIG_DIR + "/config.alloy");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const GRAFANA_ALLOY_USER = env.get("GRAFANA_ALLOY_USER", "alloy");
const GRAFANA_ALLOY_GROUP = env.get("GRAFANA_ALLOY_GROUP", "alloy");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const GRAFANA_ALLOY_HTTP_LISTEN_ADDR = env.get("GRAFANA_ALLOY_HTTP_LISTEN_ADDR", "0.0.0.0:12345");
// Alloy reads experimental components only when the stability level allows.
const GRAFANA_ALLOY_EXPERIMENTAL_FEATURES = env.bool("GRAFANA_ALLOY_EXPERIMENTAL_FEATURES", true);
const GRAFANA_ALLOY_STABILITY_LEVEL = env.get("GRAFANA_ALLOY_STABILITY_LEVEL", "experimental");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("GRAFANA_ALLOY_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const GRAFANA_ALLOY_READY_MAX_ATTEMPTS = env.int("GRAFANA_ALLOY_READY_MAX_ATTEMPTS", 30);
const GRAFANA_ALLOY_READY_ATTEMPT_INTERVAL = env.int("GRAFANA_ALLOY_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// The bundled example config installed by forge, used to seed a missing config
// file so a bare docker run works out of the box.
const GRAFANA_ALLOY_DEFAULT_CONFIG = "/etc/alloy/config.alloy";

// httpPort — numeric port parsed out of the listen address for the probe.
function httpPort() {
	const addr = String(GRAFANA_ALLOY_HTTP_LISTEN_ADDR);
	const idx = addr.lastIndexOf(":");
	return idx >= 0 ? addr.slice(idx + 1) : "12345";
}

module.exports = {
	GRAFANA_ALLOY_CONFIG_DIR,
	GRAFANA_ALLOY_DATA_DIR,
	GRAFANA_ALLOY_LOG_DIR,
	GRAFANA_ALLOY_RUN_DIR,
	GRAFANA_ALLOY_BACKUP_DIR,
	GRAFANA_ALLOY_CONFIG,
	GRAFANA_ALLOY_USER,
	GRAFANA_ALLOY_GROUP,
	GRAFANA_ALLOY_HTTP_LISTEN_ADDR,
	GRAFANA_ALLOY_EXPERIMENTAL_FEATURES,
	GRAFANA_ALLOY_STABILITY_LEVEL,
	SLEEP_MODE,
	GRAFANA_ALLOY_READY_MAX_ATTEMPTS,
	GRAFANA_ALLOY_READY_ATTEMPT_INTERVAL,
	GRAFANA_ALLOY_DEFAULT_CONFIG,
	httpPort,
};
