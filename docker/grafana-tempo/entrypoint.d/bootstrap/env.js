// env.js — Grafana Tempo environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const GRAFANA_TEMPO_CONFIG_DIR = env.get("GRAFANA_TEMPO_CONFIG_DIR", "/opt/containers/config");
const GRAFANA_TEMPO_DATA_DIR = env.get("GRAFANA_TEMPO_DATA_DIR", "/opt/containers/data");
const GRAFANA_TEMPO_LOG_DIR = env.get("GRAFANA_TEMPO_LOG_DIR", "/opt/containers/logs");
const GRAFANA_TEMPO_RUN_DIR = env.get("GRAFANA_TEMPO_RUN_DIR", "/opt/containers/run");
const GRAFANA_TEMPO_BACKUP_DIR = env.get("GRAFANA_TEMPO_BACKUP_DIR", "/opt/containers/backup");

const GRAFANA_TEMPO_CONFIG = env.get("GRAFANA_TEMPO_CONFIG", GRAFANA_TEMPO_CONFIG_DIR + "/tempo.yaml");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const GRAFANA_TEMPO_USER = env.get("GRAFANA_TEMPO_USER", "tempo");
const GRAFANA_TEMPO_GROUP = env.get("GRAFANA_TEMPO_GROUP", "tempo");

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
const GRAFANA_TEMPO_LISTEN_PORT_HTTP = env.get("GRAFANA_TEMPO_LISTEN_PORT_HTTP", "3200");
const GRAFANA_TEMPO_TARGET = env.get("GRAFANA_TEMPO_TARGET", "scalable-single-binary");
// The container IP is not known at config-generation time; the worker address
// defaults to the container's own IP:9095.
const GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER = env.get("GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER", "");

// ---------------------------------------------------------------------------
// Storage backend: local (default) or s3.
// ---------------------------------------------------------------------------
const GRAFANA_TEMPO_STORAGE_BACKEND = env.get("GRAFANA_TEMPO_STORAGE_BACKEND", "local");
const GRAFANA_TEMPO_S3_BUCKET = env.get("GRAFANA_TEMPO_S3_BUCKET", "");
const GRAFANA_TEMPO_S3_ENDPOINT = env.get("GRAFANA_TEMPO_S3_ENDPOINT", "");
const GRAFANA_TEMPO_S3_ACCESS_KEY = env.get("GRAFANA_TEMPO_S3_ACCESS_KEY", "");
const GRAFANA_TEMPO_S3_SECRET_KEY = env.get("GRAFANA_TEMPO_S3_SECRET_KEY", "");
const GRAFANA_TEMPO_S3_INSECURE = env.get("GRAFANA_TEMPO_S3_INSECURE", "false");
const GRAFANA_TEMPO_S3_REGION = env.get("GRAFANA_TEMPO_S3_REGION", "");

// ---------------------------------------------------------------------------
// Metrics generator / overrides / memberlist
// ---------------------------------------------------------------------------
const STREAM_OVER_HTTP_ENABLED = env.get("STREAM_OVER_HTTP_ENABLED", "");
const ENABLE_OVERRIDE_DEFAULT_METRICS_GENERATOR = env.bool("ENABLE_OVERRIDE_DEFAULT_METRICS_GENERATOR");
const OVERRIDE_DEFAULT_METRICS_GENERATOR_PROCESSORS = env.get(
	"OVERRIDE_DEFAULT_METRICS_GENERATOR_PROCESSORS",
	"service-graphs,span-metrics",
);
// Faithful to the bash original: the guard checks ENABLE_GENERATIVE_HISTOGRAMS
// but the emitted value comes from GENERATE_NATIVE_HISTOGRAMS.
const ENABLE_GENERATIVE_HISTOGRAMS = env.get("ENABLE_GENERATIVE_HISTOGRAMS", "");
const GENERATE_NATIVE_HISTOGRAMS = env.get("GENERATE_NATIVE_HISTOGRAMS", "both");
const ENABLE_MEMBERLIST = env.bool("ENABLE_MEMBERLIST");
const MEMBERLIST_BIND_PORT = env.get("MEMBERLIST_BIND_PORT", "7946");
const MEMBERLIST_ABORT_IF_CLUSTER_JOIN_FAILS = env.get("MEMBERLIST_ABORT_IF_CLUSTER_JOIN_FAILS", "false");
const MEMBERLIST_JOIN_MEMBERS = env.get("MEMBERLIST_JOIN_MEMBERS", "");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("GRAFANA_TEMPO_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const GRAFANA_TEMPO_READY_MAX_ATTEMPTS = env.int("GRAFANA_TEMPO_READY_MAX_ATTEMPTS", 30);
const GRAFANA_TEMPO_READY_ATTEMPT_INTERVAL = env.int("GRAFANA_TEMPO_READY_ATTEMPT_INTERVAL", 1);

module.exports = {
	GRAFANA_TEMPO_CONFIG_DIR,
	GRAFANA_TEMPO_DATA_DIR,
	GRAFANA_TEMPO_LOG_DIR,
	GRAFANA_TEMPO_RUN_DIR,
	GRAFANA_TEMPO_BACKUP_DIR,
	GRAFANA_TEMPO_CONFIG,
	GRAFANA_TEMPO_USER,
	GRAFANA_TEMPO_GROUP,
	GRAFANA_TEMPO_LISTEN_PORT_HTTP,
	GRAFANA_TEMPO_TARGET,
	GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER,
	GRAFANA_TEMPO_STORAGE_BACKEND,
	GRAFANA_TEMPO_S3_BUCKET,
	GRAFANA_TEMPO_S3_ENDPOINT,
	GRAFANA_TEMPO_S3_ACCESS_KEY,
	GRAFANA_TEMPO_S3_SECRET_KEY,
	GRAFANA_TEMPO_S3_INSECURE,
	GRAFANA_TEMPO_S3_REGION,
	STREAM_OVER_HTTP_ENABLED,
	ENABLE_OVERRIDE_DEFAULT_METRICS_GENERATOR,
	OVERRIDE_DEFAULT_METRICS_GENERATOR_PROCESSORS,
	ENABLE_GENERATIVE_HISTOGRAMS,
	GENERATE_NATIVE_HISTOGRAMS,
	ENABLE_MEMBERLIST,
	MEMBERLIST_BIND_PORT,
	MEMBERLIST_ABORT_IF_CLUSTER_JOIN_FAILS,
	MEMBERLIST_JOIN_MEMBERS,
	SLEEP_MODE,
	GRAFANA_TEMPO_READY_MAX_ATTEMPTS,
	GRAFANA_TEMPO_READY_ATTEMPT_INTERVAL,
};
