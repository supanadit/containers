// env.js — MinIO environment configuration.
//
// Single source of truth for every environment-driven setting. Booleans use
// env.bool() so they arrive as real JS booleans.
//
// Secrets: MinIO natively accepts MINIO_ROOT_USER_FILE / MINIO_ROOT_PASSWORD_FILE
// (paths to files containing the value). Those are preferred because an inline
// MINIO_ROOT_PASSWORD is visible to every process in the container (and in
// `docker inspect`). The inline variables remain supported for compatibility.
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>). MinIO uses
// "drives", so the data directory holds one or more drive directories.
// ---------------------------------------------------------------------------
const MINIO_DATA_DIR = env.get("MINIO_DATA_DIR", "/opt/containers/data");
const MINIO_CONFIG_DIR = env.get("MINIO_CONFIG_DIR", "/opt/containers/config");
const MINIO_LOG_DIR = env.get("MINIO_LOG_DIR", "/opt/containers/logs");
const MINIO_RUN_DIR = env.get("MINIO_RUN_DIR", "/opt/containers/run");
const MINIO_BACKUP_DIR = env.get("MINIO_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const MINIO_USER = env.get("MINIO_USER", "minio");
const MINIO_GROUP = env.get("MINIO_GROUP", "minio");

// ---------------------------------------------------------------------------
// Listeners
// ---------------------------------------------------------------------------
const MINIO_ADDRESS = env.get("MINIO_ADDRESS", ":9000");
const MINIO_CONSOLE_ADDRESS = env.get("MINIO_CONSOLE_ADDRESS", ":9001");

// ---------------------------------------------------------------------------
// Credentials. *_FILE wins when both are set (file-based secrets are not
// exposed to other processes).
// ---------------------------------------------------------------------------
const MINIO_ROOT_USER = env.get("MINIO_ROOT_USER", "");
const MINIO_ROOT_PASSWORD = env.get("MINIO_ROOT_PASSWORD", "");
const MINIO_ROOT_USER_FILE = env.get("MINIO_ROOT_USER_FILE", "");
const MINIO_ROOT_PASSWORD_FILE = env.get("MINIO_ROOT_PASSWORD_FILE", "");
// Deprecated aliases MinIO still honours.
const MINIO_ACCESS_KEY = env.get("MINIO_ACCESS_KEY", "");
const MINIO_SECRET_KEY = env.get("MINIO_SECRET_KEY", "");

// ---------------------------------------------------------------------------
// Browser redirect URL (console link). Derived from the container IP in
// standalone mode; must be set explicitly (or left empty) in distributed mode,
// where a per-node IP would make the consoles mismatch.
// ---------------------------------------------------------------------------
const MINIO_BROWSER_REDIRECT_URL = env.get("MINIO_BROWSER_REDIRECT_URL", "");

// ---------------------------------------------------------------------------
// Distributed mode. MINIO_DISTRIBUTED_NODES is a MinIO drive expansion such as
// "http://minio{1...4}/data{1...4}".
// ---------------------------------------------------------------------------
const MINIO_DISTRIBUTED_MODE_ENABLED = env.bool("MINIO_DISTRIBUTED_MODE_ENABLED");
const MINIO_DISTRIBUTED_NODES = env.get("MINIO_DISTRIBUTED_NODES", "");

// ---------------------------------------------------------------------------
// Extra drives for a single-node multi-drive pool, e.g.
// "/opt/containers/data/disk{1...4}" or a comma-separated list of paths. Appended
// to the server argument list (MinIO accepts N drive paths).
// ---------------------------------------------------------------------------
const MINIO_EXTRA_DRIVES = env.get("MINIO_EXTRA_DRIVES", "");

// ---------------------------------------------------------------------------
// Server options
// ---------------------------------------------------------------------------
// Comma-separated list of additional MinIO server flags/args passed through
// verbatim (e.g. "--certs-dir,/opt/containers/config/certs"). This is the only
// supported escape hatch; MinIO needs its own flags and ezx owns the argv.
const MINIO_EXTRA_ARGS = env.get("MINIO_EXTRA_ARGS", "");

// ---------------------------------------------------------------------------
// Logging / lifecycle
// ---------------------------------------------------------------------------
const LOG_LEVEL = env.get("LOG_LEVEL", "info");
// MinIO's own log level (MINIO_LOG_LEVEL) — kept distinct from the container-wide
// LOG_LEVEL used by ezx.
const MINIO_LOG_LEVEL = env.get("MINIO_LOG_LEVEL", "");

// SLEEP_MODE is the cross-container convention; MINIO_SLEEP_MODE is kept as a
// backwards-compatible alias.
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("MINIO_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const MINIO_READY_MAX_ATTEMPTS = env.int("MINIO_READY_MAX_ATTEMPTS", 30);
const MINIO_READY_ATTEMPT_INTERVAL = env.int("MINIO_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
// splitList — split a comma-separated env value into trimmed non-empty parts.
function splitList(value) {
	return String(value)
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean);
}

// portOf — the port out of a ":9000" / "0.0.0.0:9000" style listen address.
function portOf(addr) {
	const s = String(addr);
	const idx = s.lastIndexOf(":");
	return idx >= 0 ? s.slice(idx + 1) : s;
}

// useRootUserFile — a file-based root user/credential pair is in play.
function useCredentialsFile() {
	return !!MINIO_ROOT_USER_FILE || !!MINIO_ROOT_PASSWORD_FILE;
}

module.exports = {
	// directories
	MINIO_DATA_DIR,
	MINIO_CONFIG_DIR,
	MINIO_LOG_DIR,
	MINIO_RUN_DIR,
	MINIO_BACKUP_DIR,
	// identity
	MINIO_USER,
	MINIO_GROUP,
	// listeners
	MINIO_ADDRESS,
	MINIO_CONSOLE_ADDRESS,
	// credentials
	MINIO_ROOT_USER,
	MINIO_ROOT_PASSWORD,
	MINIO_ROOT_USER_FILE,
	MINIO_ROOT_PASSWORD_FILE,
	MINIO_ACCESS_KEY,
	MINIO_SECRET_KEY,
	// browser
	MINIO_BROWSER_REDIRECT_URL,
	// distributed
	MINIO_DISTRIBUTED_MODE_ENABLED,
	MINIO_DISTRIBUTED_NODES,
	MINIO_EXTRA_DRIVES,
	MINIO_EXTRA_ARGS,
	// logging / lifecycle
	LOG_LEVEL,
	MINIO_LOG_LEVEL,
	SLEEP_MODE,
	// readiness
	MINIO_READY_MAX_ATTEMPTS,
	MINIO_READY_ATTEMPT_INTERVAL,
	// helpers
	splitList,
	portOf,
	useCredentialsFile,
};
