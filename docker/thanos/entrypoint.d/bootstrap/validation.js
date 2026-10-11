// validation.js — environment validation, mirroring the checks the bash
// entrypoint performed before starting Thanos.
const { env, fs, log } = require("ezx");
const {
	THANOS_COMPONENT,
	THANOS_S3_BUCKET,
	THANOS_S3_ENDPOINT,
	THANOS_S3_ACCESS_KEY,
	THANOS_S3_SECRET_KEY,
	THANOS_OBJSTORE_CONFIG,
	THANOS_OBJSTORE_CONFIG_FILE,
	THANOS_RECEIVE_HASHRING_FILE,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE,
	THANOS_STORE_INDEX_CACHE_CONFIG_FILE,
	THANOS_STORE_CACHING_BUCKET_CONFIG_FILE,
	THANOS_DATA_DIR,
} = require("./env");

// KNOWN_COMPONENTS — the components the entrypoint understands.
const KNOWN_COMPONENTS = ["query", "query-frontend", "sidecar", "store", "receive", "rule", "compact"];

// OBJSTORE_COMPONENTS — components that read the object store. The bash
// entrypoint only attached the objstore flags for these.
const OBJSTORE_COMPONENTS = ["sidecar", "store", "receive", "rule", "compact"];

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateComponent — reject an unknown THANOS_COMPONENT (the bash case
// statement fell through to "Unknown component: ..." and exited 1).
function validateComponent() {
	if (!KNOWN_COMPONENTS.includes(THANOS_COMPONENT)) {
		log.error("Unknown component: " + THANOS_COMPONENT);
		log.error("Supported components: " + KNOWN_COMPONENTS.join(", "));
		return false;
	}
	return true;
}

// validateS3 — the S3 shorthand needs all four values, or none. A partial set
// is almost always a typo'd env var, so it is reported instead of silently
// starting without an object store.
function validateS3() {
	const missing = [];
	if (THANOS_S3_BUCKET) missing.push("THANOS_S3_BUCKET");
	if (THANOS_S3_ENDPOINT) missing.push("THANOS_S3_ENDPOINT");
	if (THANOS_S3_ACCESS_KEY) missing.push("THANOS_S3_ACCESS_KEY");
	if (THANOS_S3_SECRET_KEY) missing.push("THANOS_S3_SECRET_KEY");
	if (missing.length === 0) return true;

	const provided = [THANOS_S3_BUCKET, THANOS_S3_ENDPOINT, THANOS_S3_ACCESS_KEY, THANOS_S3_SECRET_KEY].filter(
		Boolean,
	).length;
	if (provided === 4) return true;

	const absent = ["THANOS_S3_BUCKET", "THANOS_S3_ENDPOINT", "THANOS_S3_ACCESS_KEY", "THANOS_S3_SECRET_KEY"].filter(
		(n) => !env.get(n, ""),
	);
	log.error("Incomplete S3 configuration. Missing: " + absent.join(", "));
	log.error("Set all four S3 variables, or use THANOS_OBJSTORE_CONFIG / THANOS_OBJSTORE_CONFIG_FILE.");
	return absent.length === 4;
}

// validateRequiredObjstore — store, receive and rule cannot run without an
// object store. The previous entrypoint started them anyway and let Thanos fail
// obscurely at boot; fail fast with a clear message instead.
function validateRequiredObjstore() {
	if (!OBJSTORE_COMPONENTS.includes(THANOS_COMPONENT)) return true;
	if (THANOS_OBJSTORE_CONFIG || THANOS_OBJSTORE_CONFIG_FILE) return true;
	if (THANOS_S3_BUCKET && THANOS_S3_ENDPOINT && THANOS_S3_ACCESS_KEY && THANOS_S3_SECRET_KEY) return true;
	// A mounted objstore file that exists also satisfies the requirement.
	const candidates = [
		THANOS_OBJSTORE_CONFIG_FILE,
		"/opt/containers/config/objstore.yaml",
		"/opt/containers/config/objstore.yml",
	].filter(Boolean);
	for (const c of candidates) {
		if (fs.exists(c)) return true;
	}
	if (THANOS_COMPONENT === "sidecar") return true;
	log.error("Thanos " + THANOS_COMPONENT + " requires an object store configuration.");
	log.error(
		"Set THANOS_S3_BUCKET/ENDPOINT/ACCESS_KEY/SECRET_KEY, THANOS_OBJSTORE_CONFIG, or THANOS_OBJSTORE_CONFIG_FILE.",
	);
	return false;
}

// validateFiles — declared config files and the data dir must be usable.
function validateFiles() {
	if (THANOS_RECEIVE_HASHRING_FILE && !fs.exists(THANOS_RECEIVE_HASHRING_FILE)) {
		log.error("THANOS_RECEIVE_HASHRING_FILE does not exist: " + THANOS_RECEIVE_HASHRING_FILE);
		return false;
	}
	const files = [
		["THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE", THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE],
		["THANOS_STORE_INDEX_CACHE_CONFIG_FILE", THANOS_STORE_INDEX_CACHE_CONFIG_FILE],
		["THANOS_STORE_CACHING_BUCKET_CONFIG_FILE", THANOS_STORE_CACHING_BUCKET_CONFIG_FILE],
		["THANOS_OBJSTORE_CONFIG_FILE", THANOS_OBJSTORE_CONFIG_FILE],
	];
	for (const [name, path] of files) {
		if (path && !fs.exists(path)) {
			log.error(name + " does not exist: " + path);
			return false;
		}
	}
	// The data dir is only required by the components that persist TSDB blocks.
	if (["sidecar", "store", "receive", "rule", "compact"].includes(THANOS_COMPONENT)) {
		if (!fs.exists(THANOS_DATA_DIR)) {
			log.error("THANOS_DATA_DIR does not exist: " + THANOS_DATA_DIR);
			return false;
		}
	}
	return true;
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	const ok = validateComponent() && validateS3() && validateRequiredObjstore();
	if (!ok) return false;

	const checks = [
		["thanos", commandExists("thanos")],
		["data directory", validateFiles()],
	];
	for (const [name, passed] of checks) {
		if (!passed) {
			log.error("Missing dependency: " + name);
			return false;
		}
	}
	return true;
}

module.exports = {
	validateEnvironment,
	validateComponent,
	validateS3,
	validateRequiredObjstore,
	validateFiles,
	commandExists,
	KNOWN_COMPONENTS,
	OBJSTORE_COMPONENTS,
};
