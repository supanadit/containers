// env.js — Grafana Pyroscope environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy and
// would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const PYROSCOPE_DATA_DIR = env.get("PYROSCOPE_DATA_DIR", "/opt/containers/data");
const PYROSCOPE_CONFIG_DIR = env.get("PYROSCOPE_CONFIG_DIR", "/opt/containers/config");
const PYROSCOPE_LOG_DIR = env.get("PYROSCOPE_LOG_DIR", "/opt/containers/logs");
const PYROSCOPE_RUN_DIR = env.get("PYROSCOPE_RUN_DIR", "/opt/containers/run");
const PYROSCOPE_BACKUP_DIR = env.get("PYROSCOPE_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const PYROSCOPE_USER = env.get("PYROSCOPE_USER", "pyroscope");
const PYROSCOPE_GROUP = env.get("PYROSCOPE_GROUP", "pyroscope");

// ---------------------------------------------------------------------------
// Core / component selection
// ---------------------------------------------------------------------------
// Default component is all (single-binary mode).
const PYROSCOPE_COMPONENT = env.get("PYROSCOPE_COMPONENT", "all");

// Server configuration. Empty means "let the component-specific default apply".
const PYROSCOPE_HTTP_ADDRESS = env.get("PYROSCOPE_HTTP_ADDRESS", "");
const PYROSCOPE_GRPC_ADDRESS = env.get("PYROSCOPE_GRPC_ADDRESS", "");

// Data paths
const PYROSCOPE_DATA_PATH = env.get("PYROSCOPE_DATA_PATH", "/opt/containers/data");
const PYROSCOPE_COMPACTOR_DATA_DIR = env.get("PYROSCOPE_COMPACTOR_DATA_DIR", "/opt/containers/data/compactor");

// Log configuration
const PYROSCOPE_LOG_LEVEL = env.get("PYROSCOPE_LOG_LEVEL", "info");
const PYROSCOPE_LOG_FORMAT = env.get("PYROSCOPE_LOG_FORMAT", "logfmt");

// Memberlist configuration
const PYROSCOPE_MEMBERLIST_JOIN = env.get("PYROSCOPE_MEMBERLIST_JOIN", "");
const PYROSCOPE_MEMBERLIST_BIND_PORT = env.get("PYROSCOPE_MEMBERLIST_BIND_PORT", "7946");
const PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR = env.get("PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR", "");
const PYROSCOPE_MEMBERLIST_ADVERTISE_PORT = env.get("PYROSCOPE_MEMBERLIST_ADVERTISE_PORT", "7946");

// Multitenancy
const PYROSCOPE_AUTH_MULTITENANCY_ENABLED = env.bool("PYROSCOPE_AUTH_MULTITENANCY_ENABLED");

// Storage backend configuration
const PYROSCOPE_STORAGE_BACKEND = env.get("PYROSCOPE_STORAGE_BACKEND", "");

// S3 Storage Configuration
const PYROSCOPE_STORAGE_S3_BUCKET = env.get("PYROSCOPE_STORAGE_S3_BUCKET", "");
const PYROSCOPE_STORAGE_S3_ENDPOINT = env.get("PYROSCOPE_STORAGE_S3_ENDPOINT", "");
const PYROSCOPE_STORAGE_S3_REGION = env.get("PYROSCOPE_STORAGE_S3_REGION", "");
const PYROSCOPE_STORAGE_S3_ACCESS_KEY = env.get("PYROSCOPE_STORAGE_S3_ACCESS_KEY", "");
const PYROSCOPE_STORAGE_S3_SECRET_KEY = env.get("PYROSCOPE_STORAGE_S3_SECRET_KEY", "");
const PYROSCOPE_STORAGE_S3_INSECURE = env.bool("PYROSCOPE_STORAGE_S3_INSECURE");

// GCS Storage Configuration
const PYROSCOPE_STORAGE_GCS_BUCKET = env.get("PYROSCOPE_STORAGE_GCS_BUCKET", "");
const PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT = env.get("PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT", "");

// Azure Storage Configuration
const PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME = env.get("PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME", "");
const PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY = env.get("PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY", "");
const PYROSCOPE_STORAGE_AZURE_CONTAINER = env.get("PYROSCOPE_STORAGE_AZURE_CONTAINER", "");

// Filesystem Storage Configuration
const PYROSCOPE_STORAGE_FILESYSTEM_DIR = env.get("PYROSCOPE_STORAGE_FILESYSTEM_DIR", "/opt/containers/data/shared");

// Storage prefix
const PYROSCOPE_STORAGE_PREFIX = env.get("PYROSCOPE_STORAGE_PREFIX", "");

// Distributor configuration
const PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR = env.get("PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR", "1");
const PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB = env.get("PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB", "4");
const PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB = env.get("PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB", "2");
const PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED = env.bool("PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED");

// Ingester configuration
const PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT = env.get("PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT", "5000");
const PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT = env.get("PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT", "0");
const PYROSCOPE_INGESTER_AVAILABILITY_ZONE = env.get("PYROSCOPE_INGESTER_AVAILABILITY_ZONE", "");

// Compactor configuration
const PYROSCOPE_COMPACTOR_RETENTION_PERIOD = env.get("PYROSCOPE_COMPACTOR_RETENTION_PERIOD", "");
const PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED = env.bool("PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED", true);

// Store Gateway configuration
const PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE = env.get("PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE", "0");
const PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED = env.bool("PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED");

// Querier configuration
const PYROSCOPE_QUERIER_MAX_QUERY_LENGTH = env.get("PYROSCOPE_QUERIER_MAX_QUERY_LENGTH", "1d");
const PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK = env.get("PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK", "7d");
const PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM = env.get("PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM", "0");
const PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL = env.get("PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL", "");

// Query Frontend configuration
const PYROSCOPE_QUERY_FRONTEND_ADDRESS = env.get("PYROSCOPE_QUERY_FRONTEND_ADDRESS", "");

// Query Scheduler configuration
const PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS = env.get("PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS", "100");

// Ring store configuration
const PYROSCOPE_RING_STORE = env.get("PYROSCOPE_RING_STORE", "memberlist");

// ---------------------------------------------------------------------------
// Testing / debugging / readiness
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("PYROSCOPE_SLEEP_MODE", false);
const PYROSCOPE_READY_MAX_ATTEMPTS = env.int("PYROSCOPE_READY_MAX_ATTEMPTS", 30);
const PYROSCOPE_READY_ATTEMPT_INTERVAL = env.int("PYROSCOPE_READY_ATTEMPT_INTERVAL", 1);

// Binaries
const PYROSCOPE_BIN = env.get("PYROSCOPE_BIN", "/usr/share/grafana/pyroscope");

// componentDefaults — HTTP/GRPC default address per component (from the bash
// case statement). Empty entries mean the component has no default and the
// address stays unset.
const COMPONENT_DEFAULTS = {
	all: { http: ":4040", grpc: ":9095" },
	distributor: { http: ":4040", grpc: ":9095" },
	ingester: { http: "", grpc: ":9096" },
	compactor: { http: "", grpc: ":9095" },
	querier: { http: ":4046", grpc: ":9100" },
	"store-gateway": { http: "", grpc: ":9098" },
	"query-frontend": { http: ":4047", grpc: ":9101" },
	"query-scheduler": { http: "", grpc: ":9099" },
};

// KNOWN_COMPONENTS — the components the entrypoint understands.
const KNOWN_COMPONENTS = [
	"all",
	"distributor",
	"ingester",
	"compactor",
	"querier",
	"store-gateway",
	"query-frontend",
	"query-scheduler",
];

module.exports = {
	PYROSCOPE_DATA_DIR,
	PYROSCOPE_CONFIG_DIR,
	PYROSCOPE_LOG_DIR,
	PYROSCOPE_RUN_DIR,
	PYROSCOPE_BACKUP_DIR,
	PYROSCOPE_USER,
	PYROSCOPE_GROUP,
	PYROSCOPE_COMPONENT,
	PYROSCOPE_HTTP_ADDRESS,
	PYROSCOPE_GRPC_ADDRESS,
	PYROSCOPE_DATA_PATH,
	PYROSCOPE_COMPACTOR_DATA_DIR,
	PYROSCOPE_LOG_LEVEL,
	PYROSCOPE_LOG_FORMAT,
	PYROSCOPE_MEMBERLIST_JOIN,
	PYROSCOPE_MEMBERLIST_BIND_PORT,
	PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR,
	PYROSCOPE_MEMBERLIST_ADVERTISE_PORT,
	PYROSCOPE_AUTH_MULTITENANCY_ENABLED,
	PYROSCOPE_STORAGE_BACKEND,
	PYROSCOPE_STORAGE_S3_BUCKET,
	PYROSCOPE_STORAGE_S3_ENDPOINT,
	PYROSCOPE_STORAGE_S3_REGION,
	PYROSCOPE_STORAGE_S3_ACCESS_KEY,
	PYROSCOPE_STORAGE_S3_SECRET_KEY,
	PYROSCOPE_STORAGE_S3_INSECURE,
	PYROSCOPE_STORAGE_GCS_BUCKET,
	PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT,
	PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME,
	PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY,
	PYROSCOPE_STORAGE_AZURE_CONTAINER,
	PYROSCOPE_STORAGE_FILESYSTEM_DIR,
	PYROSCOPE_STORAGE_PREFIX,
	PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR,
	PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB,
	PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB,
	PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED,
	PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT,
	PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT,
	PYROSCOPE_INGESTER_AVAILABILITY_ZONE,
	PYROSCOPE_COMPACTOR_RETENTION_PERIOD,
	PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED,
	PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE,
	PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED,
	PYROSCOPE_QUERIER_MAX_QUERY_LENGTH,
	PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK,
	PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM,
	PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL,
	PYROSCOPE_QUERY_FRONTEND_ADDRESS,
	PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS,
	PYROSCOPE_RING_STORE,
	SLEEP_MODE,
	PYROSCOPE_READY_MAX_ATTEMPTS,
	PYROSCOPE_READY_ATTEMPT_INTERVAL,
	PYROSCOPE_BIN,
	COMPONENT_DEFAULTS,
	KNOWN_COMPONENTS,
};
