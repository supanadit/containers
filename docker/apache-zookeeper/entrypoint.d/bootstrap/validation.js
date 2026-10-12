// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	ZOOKEEPER_CONFIG_FILE,
	ZOOKEEPER_DATA_DIR,
	ZOOKEEPER_CLIENT_PORT,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	if (!commandExists("zkServer.sh")) {
		log.error("Missing dependency: zkServer.sh");
		return false;
	}
	const port = parseInt(String(ZOOKEEPER_CLIENT_PORT), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("ZOOKEEPER_CLIENT_PORT is not a valid port: " + ZOOKEEPER_CLIENT_PORT);
		return false;
	}
	if (!fs.exists(ZOOKEEPER_DATA_DIR)) {
		log.error("ZOOKEEPER_DATA_DIR does not exist: " + ZOOKEEPER_DATA_DIR);
		return false;
	}
	// The config is seeded by config.js before this runs.
	if (!fs.exists(ZOOKEEPER_CONFIG_FILE)) {
		log.error("ZooKeeper configuration file not found at " + ZOOKEEPER_CONFIG_FILE);
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
