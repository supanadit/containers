// env.js — Grafana Loki environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const GRAFANA_LOKI_CONFIG_DIR = env.get("GRAFANA_LOKI_CONFIG_DIR", "/opt/containers/config");
const GRAFANA_LOKI_DATA_DIR = env.get("GRAFANA_LOKI_DATA_DIR", "/opt/containers/data");
const GRAFANA_LOKI_LOG_DIR = env.get("GRAFANA_LOKI_LOG_DIR", "/opt/containers/logs");
const GRAFANA_LOKI_RUN_DIR = env.get("GRAFANA_LOKI_RUN_DIR", "/opt/containers/run");
const GRAFANA_LOKI_BACKUP_DIR = env.get("GRAFANA_LOKI_BACKUP_DIR", "/opt/containers/backup");

const GRAFANA_LOKI_CONFIG = env.get("GRAFANA_LOKI_CONFIG", GRAFANA_LOKI_CONFIG_DIR + "/loki.yaml");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const GRAFANA_LOKI_USER = env.get("GRAFANA_LOKI_USER", "loki");
const GRAFANA_LOKI_GROUP = env.get("GRAFANA_LOKI_GROUP", "loki");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
// Available targets: read, write, backend (unset = "all").
// Docs: https://grafana.com/docs/loki/latest/get-started/components
const GRAFANA_LOKI_TARGET = env.get("GRAFANA_LOKI_TARGET", "");
const GRAFANA_LOKI_LISTEN_PORT_HTTP = env.get("GRAFANA_LOKI_LISTEN_PORT_HTTP", "3100");
const GRAFANA_LOKI_LISTEN_PORT_GRPC = env.get("GRAFANA_LOKI_LISTEN_PORT_GRPC", "9096");
const GRAFANA_LOKI_INSTANCE_ADDRESS = env.get("GRAFANA_LOKI_INSTANCE_ADDRESS", "");
// Comma-separated memberlist join members (enables clustering when set).
const GRAFANA_LOKI_MEMBERLIST = env.get("GRAFANA_LOKI_MEMBERLIST", "");
const GRAFANA_LOKI_COMPACTOR_ADDRESS = env.get("GRAFANA_LOKI_COMPACTOR_ADDRESS", "");

// ---------------------------------------------------------------------------
// Storage backend: filesystem (default) or s3.
// ---------------------------------------------------------------------------
const GRAFANA_LOKI_STORAGE_BACKEND = env.get("GRAFANA_LOKI_STORAGE_BACKEND", "filesystem");
const GRAFANA_LOKI_S3_BUCKET = env.get("GRAFANA_LOKI_S3_BUCKET", "loki");
const GRAFANA_LOKI_S3_ENDPOINT = env.get("GRAFANA_LOKI_S3_ENDPOINT", "s3.amazonaws.com");
const GRAFANA_LOKI_S3_ACCESS_KEY = env.get("GRAFANA_LOKI_S3_ACCESS_KEY", "your-access-key");
const GRAFANA_LOKI_S3_SECRET_KEY = env.get("GRAFANA_LOKI_S3_SECRET_KEY", "your-secret-key");
const GRAFANA_LOKI_S3_REGION = env.get("GRAFANA_LOKI_S3_REGION", "us-east-1");
const GRAFANA_LOKI_S3_FORCE_PATH_STYLE = env.get("GRAFANA_LOKI_S3_FORCE_PATH_STYLE", "true");
const GRAFANA_LOKI_S3_INSECURE = env.get("GRAFANA_LOKI_S3_INSECURE", "false");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("GRAFANA_LOKI_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const GRAFANA_LOKI_READY_MAX_ATTEMPTS = env.int("GRAFANA_LOKI_READY_MAX_ATTEMPTS", 30);
const GRAFANA_LOKI_READY_ATTEMPT_INTERVAL = env.int("GRAFANA_LOKI_READY_ATTEMPT_INTERVAL", 1);

module.exports = {
	GRAFANA_LOKI_CONFIG_DIR,
	GRAFANA_LOKI_DATA_DIR,
	GRAFANA_LOKI_LOG_DIR,
	GRAFANA_LOKI_RUN_DIR,
	GRAFANA_LOKI_BACKUP_DIR,
	GRAFANA_LOKI_CONFIG,
	GRAFANA_LOKI_USER,
	GRAFANA_LOKI_GROUP,
	GRAFANA_LOKI_TARGET,
	GRAFANA_LOKI_LISTEN_PORT_HTTP,
	GRAFANA_LOKI_LISTEN_PORT_GRPC,
	GRAFANA_LOKI_INSTANCE_ADDRESS,
	GRAFANA_LOKI_MEMBERLIST,
	GRAFANA_LOKI_COMPACTOR_ADDRESS,
	GRAFANA_LOKI_STORAGE_BACKEND,
	GRAFANA_LOKI_S3_BUCKET,
	GRAFANA_LOKI_S3_ENDPOINT,
	GRAFANA_LOKI_S3_ACCESS_KEY,
	GRAFANA_LOKI_S3_SECRET_KEY,
	GRAFANA_LOKI_S3_REGION,
	GRAFANA_LOKI_S3_FORCE_PATH_STYLE,
	GRAFANA_LOKI_S3_INSECURE,
	SLEEP_MODE,
	GRAFANA_LOKI_READY_MAX_ATTEMPTS,
	GRAFANA_LOKI_READY_ATTEMPT_INTERVAL,
};
