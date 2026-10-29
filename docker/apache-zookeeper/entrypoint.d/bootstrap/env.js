// env.js — Apache ZooKeeper environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const ZOOKEEPER_DATA_DIR = env.get("ZOOKEEPER_DATA_DIR", "/opt/containers/data");
const ZOOKEEPER_CONFIG_DIR = env.get("ZOOCFGDIR", env.get("ZOOKEEPER_CONFIG_DIR", "/opt/containers/config"));
const ZOOKEEPER_LOG_DIR = env.get("ZOOKEEPER_LOG_DIR", "/opt/containers/logs");
const ZOOKEEPER_RUN_DIR = env.get("ZOOKEEPER_RUN_DIR", "/opt/containers/run");
const ZOOKEEPER_BACKUP_DIR = env.get("ZOOKEEPER_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const ZOOKEEPER_USER = env.get("ZOOKEEPER_USER", "zookeeper");
const ZOOKEEPER_GROUP = env.get("ZOOKEEPER_GROUP", "zookeeper");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const ZOOKEEPER_HOME = env.get("ZOOKEEPER_HOME", "/opt/zookeeper");
const ZOOKEEPER_CLIENT_PORT = env.get("ZOOKEEPER_CLIENT_PORT", env.get("ZOOKEEPER_CLIENT_PORT", "2181"));
// ZooKeeper's own ZOO_* knobs stay in the zoo.cfg; the container only owns the
// log dir and data dir.
const ZOOKEEPER_TICK_TIME = env.get("ZOOKEEPER_TICK_TIME", "2000");
const ZOOKEEPER_MAX_CLIENT_CNXNS = env.get("ZOOKEEPER_MAX_CLIENT_CNXNS", "60");
const ZOOKEEPER_ADMIN_ENABLE_SERVER = env.bool("ZOOKEEPER_ADMIN_ENABLE_SERVER", false);
// 8080 belongs to the ezx health API, so the admin server moves by default.
const ZOOKEEPER_ADMIN_SERVER_PORT = env.int("ZOOKEEPER_ADMIN_SERVER_PORT", 8081);

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("ZOOKEEPER_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const ZOOKEEPER_READY_MAX_ATTEMPTS = env.int("ZOOKEEPER_READY_MAX_ATTEMPTS", 30);
const ZOOKEEPER_READY_ATTEMPT_INTERVAL = env.int("ZOOKEEPER_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const ZOOKEEPER_CONFIG_FILE = ZOOKEEPER_CONFIG_DIR + "/zoo.cfg";
const ZOOKEEPER_DATA_LOG_DIR = ZOOKEEPER_DATA_DIR + "/log";

module.exports = {
	ZOOKEEPER_DATA_DIR,
	ZOOKEEPER_CONFIG_DIR,
	ZOOKEEPER_LOG_DIR,
	ZOOKEEPER_RUN_DIR,
	ZOOKEEPER_BACKUP_DIR,
	ZOOKEEPER_USER,
	ZOOKEEPER_GROUP,
	ZOOKEEPER_HOME,
	ZOOKEEPER_CLIENT_PORT,
	ZOOKEEPER_TICK_TIME,
	ZOOKEEPER_MAX_CLIENT_CNXNS,
	ZOOKEEPER_ADMIN_ENABLE_SERVER,
	ZOOKEEPER_ADMIN_SERVER_PORT,
	SLEEP_MODE,
	ZOOKEEPER_READY_MAX_ATTEMPTS,
	ZOOKEEPER_READY_ATTEMPT_INTERVAL,
	ZOOKEEPER_CONFIG_FILE,
	ZOOKEEPER_DATA_LOG_DIR,
};
