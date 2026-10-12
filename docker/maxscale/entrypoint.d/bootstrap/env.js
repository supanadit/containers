// env.js — MariaDB MaxScale environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const MAXSCALE_CONFIG_DIR = env.get("MAXSCALE_CONFIG_DIR", "/opt/containers/config");
const MAXSCALE_DATA_DIR = env.get("MAXSCALE_DATA_DIR", "/opt/containers/data");
const MAXSCALE_LOG_DIR = env.get("MAXSCALE_LOG_DIR", "/opt/containers/logs");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const MAXSCALE_SERVICE_USER = env.get("MAXSCALE_SERVICE_USER", "maxscale");
const MAXSCALE_SERVICE_PASSWORD = env.get("MAXSCALE_SERVICE_PASSWORD", "maxscale");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const MAXSCALE_SERVICE_READWRITE_ROUTES = env.get(
	"MAXSCALE_SERVICE_READWRITE_ROUTES",
	"localhost:3306",
);
const MAXSCALE_SERVICE_READCONN_ROUTES = env.get(
	"MAXSCALE_SERVICE_READCONN_ROUTES",
	"localhost:3306",
);
const MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS = env.get(
	"MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS",
	"localhost:3306",
);
const MAXSCALE_THREADS = env.get("MAXSCALE_THREADS", "auto");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("MAXSCALE_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const MAXSCALE_READY_MAX_ATTEMPTS = env.int("MAXSCALE_READY_MAX_ATTEMPTS", 30);
const MAXSCALE_READY_ATTEMPT_INTERVAL = env.int("MAXSCALE_READY_ATTEMPT_INTERVAL", 1);
// The Read-Write listener port MaxScale serves on.
const MAXSCALE_PORT = env.get("MAXSCALE_PORT", "3306");
// The REST API (maxctrl) port.
const MAXSCALE_REST_PORT = env.get("MAXSCALE_REST_PORT", "8989");

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const MAXSCALE_CONFIG_FILE = env.get("MAXSCALE_CONFIG_FILE", "/etc/maxscale.cnf.d/generated.cnf");

module.exports = {
	MAXSCALE_CONFIG_DIR,
	MAXSCALE_DATA_DIR,
	MAXSCALE_LOG_DIR,
	MAXSCALE_SERVICE_USER,
	MAXSCALE_SERVICE_PASSWORD,
	MAXSCALE_SERVICE_READWRITE_ROUTES,
	MAXSCALE_SERVICE_READCONN_ROUTES,
	MAXSCALE_MONITOR_MARIADB_MONITOR_SERVERS,
	MAXSCALE_THREADS,
	SLEEP_MODE,
	MAXSCALE_READY_MAX_ATTEMPTS,
	MAXSCALE_READY_ATTEMPT_INTERVAL,
	MAXSCALE_PORT,
	MAXSCALE_REST_PORT,
	MAXSCALE_CONFIG_FILE,
};
