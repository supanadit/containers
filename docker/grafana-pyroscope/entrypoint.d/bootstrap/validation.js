// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	PYROSCOPE_COMPONENT,
	PYROSCOPE_STORAGE_BACKEND,
	KNOWN_COMPONENTS,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateComponent — reject an unknown PYROSCOPE_COMPONENT (the bash case
// statement printed the available components and exited 1).
function validateComponent() {
	if (!KNOWN_COMPONENTS.includes(PYROSCOPE_COMPONENT)) {
		log.error("Unknown component: " + PYROSCOPE_COMPONENT);
		log.error("Available components: " + KNOWN_COMPONENTS.join(", "));
		return false;
	}
	return true;
}

// validateStorage — in microservices mode every component except "all" needs a
// storage backend.
function validateStorage() {
	if (PYROSCOPE_COMPONENT !== "all" && !PYROSCOPE_STORAGE_BACKEND) {
		log.error("Storage backend must be configured when running in microservices mode.");
		log.error("Please set PYROSCOPE_STORAGE_BACKEND (s3, gcs, azure, or filesystem).");
		return false;
	}
	if (PYROSCOPE_STORAGE_BACKEND && !["s3", "gcs", "azure", "filesystem"].includes(PYROSCOPE_STORAGE_BACKEND)) {
		log.error("Invalid PYROSCOPE_STORAGE_BACKEND: " + PYROSCOPE_STORAGE_BACKEND + " (must be s3, gcs, azure, or filesystem)");
		return false;
	}
	return true;
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	if (!validateComponent()) return false;
	if (!validateStorage()) return false;
	if (!commandExists("pyroscope")) {
		log.error("Missing dependency: pyroscope");
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	validateComponent,
	validateStorage,
	commandExists,
};
