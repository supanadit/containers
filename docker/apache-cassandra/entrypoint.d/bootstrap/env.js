// env.js — Apache Cassandra environment configuration.
//
// Single source of truth for every environment-driven setting. The bash
// entrypoint only set CASSANDRA_HOME and JVM_OPTS; the rest are added here
// because the normalized paths and a configurable cluster are part of the
// container contract.
//
// CASSANDRA_CONF points at the full Cassandra conf directory (cassandra.yaml,
// jvm options, logback, cassandra-env.sh, ...). The release's conf tree ships
// in the image with the repo's config/cassandra.yaml copied over it at build
// time; a user mount can replace the whole directory via CASSANDRA_CONF.
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const CASSANDRA_DATA_DIR = env.get("CASSANDRA_DATA_DIR", "/opt/containers/data");
const CASSANDRA_CONFIG_DIR = env.get("CASSANDRA_CONFIG_DIR", "/opt/containers/config");
const CASSANDRA_LOG_DIR = env.get("CASSANDRA_LOG_DIR", "/opt/containers/logs");
const CASSANDRA_RUN_DIR = env.get("CASSANDRA_RUN_DIR", "/opt/containers/run");
const CASSANDRA_BACKUP_DIR = env.get("CASSANDRA_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const CASSANDRA_USER = env.get("CASSANDRA_USER", "cassandra");
const CASSANDRA_GROUP = env.get("CASSANDRA_GROUP", "cassandra");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const CASSANDRA_HOME = env.get("CASSANDRA_HOME", "/opt/cassandra");
const JVM_OPTS = env.get("JVM_OPTS", "-Xms1g -Xmx1g");
// The full conf directory the server reads. Defaults to the release conf tree
// (with the repo's cassandra.yaml baked on top).
const CASSANDRA_CONF = env.get("CASSANDRA_CONF", CASSANDRA_HOME + "/conf");
const CASSANDRA_CONFIG_FILE = env.get("CASSANDRA_CONFIG_FILE", CASSANDRA_CONF + "/cassandra.yaml");
// Optional whitespace-separated extra args for the cassandra launcher.
const CASSANDRA_EXTRA_ARGS = env.get("CASSANDRA_EXTRA_ARGS", "");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("CASSANDRA_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const CASSANDRA_READY_MAX_ATTEMPTS = env.int("CASSANDRA_READY_MAX_ATTEMPTS", 60);
const CASSANDRA_READY_ATTEMPT_INTERVAL = env.int("CASSANDRA_READY_ATTEMPT_INTERVAL", 2);
// Native client port (CQL), for the readiness TCP probe.
const CASSANDRA_NATIVE_PORT = env.get("CASSANDRA_NATIVE_PORT", "9042");

module.exports = {
	CASSANDRA_DATA_DIR,
	CASSANDRA_CONFIG_DIR,
	CASSANDRA_LOG_DIR,
	CASSANDRA_RUN_DIR,
	CASSANDRA_BACKUP_DIR,
	CASSANDRA_USER,
	CASSANDRA_GROUP,
	CASSANDRA_HOME,
	JVM_OPTS,
	CASSANDRA_CONF,
	CASSANDRA_CONFIG_FILE,
	CASSANDRA_EXTRA_ARGS,
	SLEEP_MODE,
	CASSANDRA_READY_MAX_ATTEMPTS,
	CASSANDRA_READY_ATTEMPT_INTERVAL,
	CASSANDRA_NATIVE_PORT,
};
