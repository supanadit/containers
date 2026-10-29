// validation.js — environment validation for the MinIO container.
const { fs, log } = require("ezx");
const {
	MINIO_DISTRIBUTED_MODE_ENABLED,
	MINIO_DISTRIBUTED_NODES,
	MINIO_ROOT_USER,
	MINIO_ROOT_PASSWORD,
	MINIO_ROOT_USER_FILE,
	MINIO_ROOT_PASSWORD_FILE,
	MINIO_ACCESS_KEY,
	MINIO_SECRET_KEY,
	MINIO_ADDRESS,
	MINIO_CONSOLE_ADDRESS,
} = require("./env");

// validateNodeBinary — minio must be on PATH and executable.
function validateNodeBinary() {
	return fs.which("minio");
}

// validateCredentials — MinIO refuses to start without credentials; reject a
// partial pair early with a clear message instead of letting MinIO fail.
function validateCredentials() {
	const hasUser = !!(MINIO_ROOT_USER || MINIO_ROOT_USER_FILE || MINIO_ACCESS_KEY);
	const hasPassword = !!(MINIO_ROOT_PASSWORD || MINIO_ROOT_PASSWORD_FILE || MINIO_SECRET_KEY);
	if (hasUser !== hasPassword) {
		log.error("Incomplete MinIO credentials: set both the root user and the root password (or neither).");
		return false;
	}
	if (MINIO_ROOT_USER_FILE && !fs.exists(MINIO_ROOT_USER_FILE)) {
		log.error("MINIO_ROOT_USER_FILE does not exist: " + MINIO_ROOT_USER_FILE);
		return false;
	}
	if (MINIO_ROOT_PASSWORD_FILE && !fs.exists(MINIO_ROOT_PASSWORD_FILE)) {
		log.error("MINIO_ROOT_PASSWORD_FILE does not exist: " + MINIO_ROOT_PASSWORD_FILE);
		return false;
	}
	return true;
}

// validateDistributed — distributed mode needs an expansion. In distributed mode
// MinIO refuses a single drive path, so the expansion is required, not optional.
function validateDistributed() {
	if (!MINIO_DISTRIBUTED_MODE_ENABLED) return true;
	if (!MINIO_DISTRIBUTED_NODES) {
		log.error("MINIO_DISTRIBUTED_NODES is required when MINIO_DISTRIBUTED_MODE_ENABLED is true.");
		log.error("Example: MINIO_DISTRIBUTED_NODES='http://minio{1...4}/data{1...4}'");
		return false;
	}
	return true;
}

// validatePorts — the listen addresses must end in a numeric port.
function validatePorts() {
	for (const [name, addr] of [
		["MINIO_ADDRESS", MINIO_ADDRESS],
		["MINIO_CONSOLE_ADDRESS", MINIO_CONSOLE_ADDRESS],
	]) {
		const port = parseInt(String(addr).split(":").pop(), 10);
		if (!Number.isInteger(port) || port < 1 || port > 65535) {
			log.error(name + " is not a valid listen address: " + addr);
			return false;
		}
	}
	return true;
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	const checks = [
		["minio", validateNodeBinary()],
		["credentials", validateCredentials()],
		["distributed mode", validateDistributed()],
		["ports", validatePorts()],
	];
	for (const [name, passed] of checks) {
		if (!passed) {
			log.error("Validation failed: " + name);
			return false;
		}
	}
	return true;
}

module.exports = {
	validateEnvironment,
	validateCredentials,
	validateDistributed,
	validatePorts,
	validateNodeBinary,
};
