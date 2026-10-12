// validation.js — environment validation.
const { fs, log } = require("ezx");
const { CASSANDRA_CONFIG_FILE, CASSANDRA_DATA_DIR, CASSANDRA_NATIVE_PORT } = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	if (!commandExists("cassandra")) {
		log.error("Missing dependency: cassandra");
		return false;
	}
	const port = parseInt(String(CASSANDRA_NATIVE_PORT), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("CASSANDRA_NATIVE_PORT is not a valid port: " + CASSANDRA_NATIVE_PORT);
		return false;
	}
	if (!fs.exists(CASSANDRA_DATA_DIR)) {
		log.error("CASSANDRA_DATA_DIR does not exist: " + CASSANDRA_DATA_DIR);
		return false;
	}
	// The config is seeded by config.js before this runs.
	if (!fs.exists(CASSANDRA_CONFIG_FILE)) {
		log.error("Cassandra configuration file not found at " + CASSANDRA_CONFIG_FILE);
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
