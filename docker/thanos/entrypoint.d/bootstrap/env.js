// env.js — Thanos environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const THANOS_DATA_DIR = env.get("THANOS_DATA_DIR", "/opt/containers/data");
const THANOS_CONFIG_DIR = env.get("THANOS_CONFIG_DIR", "/opt/containers/config");
const THANOS_LOG_DIR = env.get("THANOS_LOG_DIR", "/opt/containers/logs");
const THANOS_RUN_DIR = env.get("THANOS_RUN_DIR", "/opt/containers/run");
const THANOS_BACKUP_DIR = env.get("THANOS_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const THANOS_USER = env.get("THANOS_USER", "thanos");
const THANOS_GROUP = env.get("THANOS_GROUP", "thanos");

// ---------------------------------------------------------------------------
// Component selection — one image, seven components (query, query-frontend,
// sidecar, store, receive, rule, compact). Defaults to the query component,
// matching the previous entrypoint.
// ---------------------------------------------------------------------------
const THANOS_COMPONENT = env.get("THANOS_COMPONENT", "query");
const THANOS_HTTP_ADDRESS = env.get("THANOS_HTTP_ADDRESS", "0.0.0.0:10902");
const THANOS_GRPC_ADDRESS = env.get("THANOS_GRPC_ADDRESS", "0.0.0.0:10901");

// ---------------------------------------------------------------------------
// Receive
// ---------------------------------------------------------------------------
const THANOS_RECEIVE_HASHRING_FILE = env.get("THANOS_RECEIVE_HASHRING_FILE", "");
const THANOS_RECEIVE_LOCAL_ENDPOINT = env.get("THANOS_RECEIVE_LOCAL_ENDPOINT", "127.0.0.1:10901");
const THANOS_REMOTE_WRITE_ADDRESS = env.get("THANOS_REMOTE_WRITE_ADDRESS", "0.0.0.0:10903");
const THANOS_RECEIVE_REPLICATION_FACTOR = env.get("THANOS_RECEIVE_REPLICATION_FACTOR", "1");

// ---------------------------------------------------------------------------
// Sidecar
// ---------------------------------------------------------------------------
const THANOS_SIDECAR_PROMETHEUS_URL = env.get("THANOS_SIDECAR_PROMETHEUS_URL", "http://localhost:9090");
const THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED = env.bool("THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED");

// ---------------------------------------------------------------------------
// Query / query-frontend
// ---------------------------------------------------------------------------
const THANOS_REPLICA_LABEL = env.get("THANOS_REPLICA_LABEL", "");
const THANOS_QUERY_STORE_ADDRESSES = env.get("THANOS_QUERY_STORE_ADDRESSES", "");
const THANOS_QUERY_ENDPOINTS = env.get("THANOS_QUERY_ENDPOINTS", "");
const THANOS_QUERY_FRONTEND_DOWNSTREAM_URL = env.get("THANOS_QUERY_FRONTEND_DOWNSTREAM_URL", "");
const THANOS_QUERY_RANGE_SPLIT_INTERVAL = env.get("THANOS_QUERY_RANGE_SPLIT_INTERVAL", "");
const THANOS_QUERY_RANGE_MAX_RETRIES = env.get("THANOS_QUERY_RANGE_MAX_RETRIES", "");
const THANOS_LABELS_SPLIT_INTERVAL = env.get("THANOS_LABELS_SPLIT_INTERVAL", "");
// Inline YAML or a path; the inline form is written to the config volume.
const THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG = env.get("THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG", "");
const THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE = env.get(
	"THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE",
	"",
);

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------
const THANOS_STORE_INDEX_CACHE_CONFIG = env.get("THANOS_STORE_INDEX_CACHE_CONFIG", "");
const THANOS_STORE_INDEX_CACHE_CONFIG_FILE = env.get("THANOS_STORE_INDEX_CACHE_CONFIG_FILE", "");
const THANOS_STORE_CACHING_BUCKET_CONFIG = env.get("THANOS_STORE_CACHING_BUCKET_CONFIG", "");
const THANOS_STORE_CACHING_BUCKET_CONFIG_FILE = env.get("THANOS_STORE_CACHING_BUCKET_CONFIG_FILE", "");

// ---------------------------------------------------------------------------
// Compact
// ---------------------------------------------------------------------------
const THANOS_COMPACT_DOWNSAMPLING_DISABLE = env.bool("THANOS_COMPACT_DOWNSAMPLING_DISABLE");
const THANOS_COMPACT_RETENTION_RAW = env.get("THANOS_COMPACT_RETENTION_RAW", "");
const THANOS_COMPACT_RETENTION_5M = env.get("THANOS_COMPACT_RETENTION_5M", "");
const THANOS_COMPACT_RETENTION_1H = env.get("THANOS_COMPACT_RETENTION_1H", "");
const THANOS_COMPACT_CONSISTENCY_DELAY = env.get("THANOS_COMPACT_CONSISTENCY_DELAY", "30m");
const THANOS_COMPACT_COMPACTION_CONCURRENCY = env.get("THANOS_COMPACT_COMPACTION_CONCURRENCY", "1");

// ---------------------------------------------------------------------------
// Rule
// ---------------------------------------------------------------------------
const THANOS_RULE_FILES = env.get("THANOS_RULE_FILES", "");
const THANOS_ALERTMANAGERS_URL = env.get("THANOS_ALERTMANAGERS_URL", "");

// ---------------------------------------------------------------------------
// S3 object store. When THANOS_S3_BUCKET/ENDPOINT/ACCESS_KEY/SECRET_KEY are all
// set they are rendered into an objstore config file (0600) that Thanos reads
// with --objstore.config-file, so the secret never reaches the process list.
// An inline THANOS_OBJSTORE_CONFIG or a mounted
// THANOS_OBJSTORE_CONFIG_FILE always win over the S3 shorthand.
// ---------------------------------------------------------------------------
const THANOS_S3_BUCKET = env.get("THANOS_S3_BUCKET", "");
const THANOS_S3_ENDPOINT = env.get("THANOS_S3_ENDPOINT", "");
const THANOS_S3_ACCESS_KEY = env.get("THANOS_S3_ACCESS_KEY", "");
const THANOS_S3_SECRET_KEY = env.get("THANOS_S3_SECRET_KEY", "");
const THANOS_S3_INSECURE = env.bool("THANOS_S3_INSECURE");
const THANOS_S3_SIGNATURE_V2 = env.bool("THANOS_S3_SIGNATURE_V2");
// SSL/TLS
const THANOS_S3_CA_FILE = env.get("THANOS_S3_CA_FILE", "");
const THANOS_S3_CERT_FILE = env.get("THANOS_S3_CERT_FILE", "");
const THANOS_S3_KEY_FILE = env.get("THANOS_S3_KEY_FILE", "");
const THANOS_S3_INSECURE_SKIP_VERIFY = env.bool("THANOS_S3_INSECURE_SKIP_VERIFY");
// Explicit objstore overrides.
const THANOS_OBJSTORE_CONFIG = env.get("THANOS_OBJSTORE_CONFIG", "");
const THANOS_OBJSTORE_CONFIG_FILE = env.get("THANOS_OBJSTORE_CONFIG_FILE", "");

// ---------------------------------------------------------------------------
// Logging / lifecycle
// ---------------------------------------------------------------------------
const LOG_LEVEL = env.get("LOG_LEVEL", "info");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
// SLEEP_MODE is the cross-container convention; THANOS_SLEEP_MODE is kept as a
// backwards-compatible alias.
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("THANOS_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const THANOS_READY_MAX_ATTEMPTS = env.int("THANOS_READY_MAX_ATTEMPTS", 30);
const THANOS_READY_ATTEMPT_INTERVAL = env.int("THANOS_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
// Generated objstore / cache configs live on the config volume instead of
// /tmp, so they are inspectable and survive (the previous entrypoint wrote to
// /tmp/thanos_s3_config.yaml and /tmp/thanos_cache_config.yaml).
const THANOS_OBJSTORE_FILE = THANOS_CONFIG_DIR + "/thanos-objstore.yaml";
const THANOS_CACHE_CONFIG_FILE = THANOS_CONFIG_DIR + "/thanos-cache.yaml";

// HTTP port parsed out of THANOS_HTTP_ADDRESS for the readiness/health probe.
function httpPort() {
	const addr = String(THANOS_HTTP_ADDRESS);
	const idx = addr.lastIndexOf(":");
	return idx >= 0 ? addr.slice(idx + 1) : "10902";
}

// s3Configured — the S3 shorthand is complete.
function s3Configured() {
	return (
		!!THANOS_S3_BUCKET && !!THANOS_S3_ENDPOINT && !!THANOS_S3_ACCESS_KEY && !!THANOS_S3_SECRET_KEY
	);
}

module.exports = {
	// directories
	THANOS_DATA_DIR,
	THANOS_CONFIG_DIR,
	THANOS_LOG_DIR,
	THANOS_RUN_DIR,
	THANOS_BACKUP_DIR,
	// identity
	THANOS_USER,
	THANOS_GROUP,
	// component
	THANOS_COMPONENT,
	THANOS_HTTP_ADDRESS,
	THANOS_GRPC_ADDRESS,
	// receive
	THANOS_RECEIVE_HASHRING_FILE,
	THANOS_RECEIVE_LOCAL_ENDPOINT,
	THANOS_REMOTE_WRITE_ADDRESS,
	THANOS_RECEIVE_REPLICATION_FACTOR,
	// sidecar
	THANOS_SIDECAR_PROMETHEUS_URL,
	THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED,
	// query
	THANOS_REPLICA_LABEL,
	THANOS_QUERY_STORE_ADDRESSES,
	THANOS_QUERY_ENDPOINTS,
	THANOS_QUERY_FRONTEND_DOWNSTREAM_URL,
	THANOS_QUERY_RANGE_SPLIT_INTERVAL,
	THANOS_QUERY_RANGE_MAX_RETRIES,
	THANOS_LABELS_SPLIT_INTERVAL,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE,
	// store
	THANOS_STORE_INDEX_CACHE_CONFIG,
	THANOS_STORE_INDEX_CACHE_CONFIG_FILE,
	THANOS_STORE_CACHING_BUCKET_CONFIG,
	THANOS_STORE_CACHING_BUCKET_CONFIG_FILE,
	// compact
	THANOS_COMPACT_DOWNSAMPLING_DISABLE,
	THANOS_COMPACT_RETENTION_RAW,
	THANOS_COMPACT_RETENTION_5M,
	THANOS_COMPACT_RETENTION_1H,
	THANOS_COMPACT_CONSISTENCY_DELAY,
	THANOS_COMPACT_COMPACTION_CONCURRENCY,
	// rule
	THANOS_RULE_FILES,
	THANOS_ALERTMANAGERS_URL,
	// s3
	THANOS_S3_BUCKET,
	THANOS_S3_ENDPOINT,
	THANOS_S3_ACCESS_KEY,
	THANOS_S3_SECRET_KEY,
	THANOS_S3_INSECURE,
	THANOS_S3_SIGNATURE_V2,
	THANOS_S3_CA_FILE,
	THANOS_S3_CERT_FILE,
	THANOS_S3_KEY_FILE,
	THANOS_S3_INSECURE_SKIP_VERIFY,
	THANOS_OBJSTORE_CONFIG,
	THANOS_OBJSTORE_CONFIG_FILE,
	// logging / lifecycle
	LOG_LEVEL,
	SLEEP_MODE,
	// readiness
	THANOS_READY_MAX_ATTEMPTS,
	THANOS_READY_ATTEMPT_INTERVAL,
	// derived
	THANOS_OBJSTORE_FILE,
	THANOS_CACHE_CONFIG_FILE,
	httpPort,
	s3Configured,
};
