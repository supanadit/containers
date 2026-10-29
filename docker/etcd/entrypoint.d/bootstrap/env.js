// env.js — etcd environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const ETCD_DATA_DIR = env.get("ETCD_DATA_DIR", "/opt/containers/data");
const ETCD_CONFIG_DIR = env.get("ETCD_CONFIG_DIR", "/opt/containers/config");
const ETCD_LOG_DIR = env.get("ETCD_LOG_DIR", "/opt/containers/logs");
const ETCD_RUN_DIR = env.get("ETCD_RUN_DIR", "/opt/containers/run");
const ETCD_BACKUP_DIR = env.get("ETCD_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const ETCD_USER = env.get("ETCD_USER", "etcd");
const ETCD_GROUP = env.get("ETCD_GROUP", "etcd");

// ---------------------------------------------------------------------------
// Core. The container IP is not known at parse time, so the advertise URLs and
// initial cluster default to the container's own IP (resolved at startup by the
// runtime, mirroring the bash `hostname -i`).
// ---------------------------------------------------------------------------
const ETCD_NAME = env.get("ETCD_NAME", "etcd-node");
const ETCD_LISTEN_PEER_URLS = env.get("ETCD_LISTEN_PEER_URLS", "http://0.0.0.0:2380");
const ETCD_LISTEN_CLIENT_URLS = env.get("ETCD_LISTEN_CLIENT_URLS", "http://0.0.0.0:2379");
// Empty means "http://<container-ip>:2379".
const ETCD_ADVERTISE_CLIENT_URLS = env.get("ETCD_ADVERTISE_CLIENT_URLS", "");
const ETCD_INITIAL_ADVERTISE_PEER_URLS = env.get("ETCD_INITIAL_ADVERTISE_PEER_URLS", "");
const ETCD_INITIAL_CLUSTER = env.get("ETCD_INITIAL_CLUSTER", "");
const ETCD_INITIAL_CLUSTER_STATE = env.get("ETCD_INITIAL_CLUSTER_STATE", "new");
const ETCD_INITIAL_CLUSTER_TOKEN = env.get("ETCD_INITIAL_CLUSTER_TOKEN", "etcd-cluster");

// Tuning knobs (fixed defaults in the bash entrypoint).
const ETCD_HEARTBEAT_INTERVAL = env.get("ETCD_HEARTBEAT_INTERVAL", "1000");
const ETCD_ELECTION_TIMEOUT = env.get("ETCD_ELECTION_TIMEOUT", "5000");
const ETCD_SNAPSHOT_COUNT = env.get("ETCD_SNAPSHOT_COUNT", "5000");
const ETCD_AUTO_COMPACTION_RETENTION = env.get("ETCD_AUTO_COMPACTION_RETENTION", "1");
const ETCD_MAX_REQUEST_BYTES = env.get("ETCD_MAX_REQUEST_BYTES", "10485760");

// ---------------------------------------------------------------------------
// TLS. Only the cert-file variants the bash entrypoint supported are kept.
// ---------------------------------------------------------------------------
const ETCD_CERT_FILE = env.get("ETCD_CERT_FILE", "");
const ETCD_KEY_FILE = env.get("ETCD_KEY_FILE", "");
const ETCD_CLIENT_CERT_AUTH = env.bool("ETCD_CLIENT_CERT_AUTH");
const ETCD_TRUSTED_CA_FILE = env.get("ETCD_TRUSTED_CA_FILE", "");
const ETCD_PEER_CERT_FILE = env.get("ETCD_PEER_CERT_FILE", "");
const ETCD_PEER_KEY_FILE = env.get("ETCD_PEER_KEY_FILE", "");
const ETCD_PEER_CLIENT_CERT_AUTH = env.bool("ETCD_PEER_CLIENT_CERT_AUTH");
const ETCD_PEER_TRUSTED_CA_FILE = env.get("ETCD_PEER_TRUSTED_CA_FILE", "");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("ETCD_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const ETCD_READY_MAX_ATTEMPTS = env.int("ETCD_READY_MAX_ATTEMPTS", 30);
const ETCD_READY_ATTEMPT_INTERVAL = env.int("ETCD_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const ETCD_HEALTH_PORT = env.get("ETCD_HEALTH_PORT", "2379");

module.exports = {
	ETCD_DATA_DIR,
	ETCD_CONFIG_DIR,
	ETCD_LOG_DIR,
	ETCD_RUN_DIR,
	ETCD_BACKUP_DIR,
	ETCD_USER,
	ETCD_GROUP,
	ETCD_NAME,
	ETCD_LISTEN_PEER_URLS,
	ETCD_LISTEN_CLIENT_URLS,
	ETCD_ADVERTISE_CLIENT_URLS,
	ETCD_INITIAL_ADVERTISE_PEER_URLS,
	ETCD_INITIAL_CLUSTER,
	ETCD_INITIAL_CLUSTER_STATE,
	ETCD_INITIAL_CLUSTER_TOKEN,
	ETCD_HEARTBEAT_INTERVAL,
	ETCD_ELECTION_TIMEOUT,
	ETCD_SNAPSHOT_COUNT,
	ETCD_AUTO_COMPACTION_RETENTION,
	ETCD_MAX_REQUEST_BYTES,
	ETCD_CERT_FILE,
	ETCD_KEY_FILE,
	ETCD_CLIENT_CERT_AUTH,
	ETCD_TRUSTED_CA_FILE,
	ETCD_PEER_CERT_FILE,
	ETCD_PEER_KEY_FILE,
	ETCD_PEER_CLIENT_CERT_AUTH,
	ETCD_PEER_TRUSTED_CA_FILE,
	SLEEP_MODE,
	ETCD_READY_MAX_ATTEMPTS,
	ETCD_READY_ATTEMPT_INTERVAL,
	ETCD_HEALTH_PORT,
};
