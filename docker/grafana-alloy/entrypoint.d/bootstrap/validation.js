// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	GRAFANA_ALLOY_CONFIG,
	GRAFANA_ALLOY_DATA_DIR,
	GRAFANA_ALLOY_HTTP_LISTEN_ADDR,
	httpPort,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	const checks = [
		["alloy", commandExists("alloy")],
		["data directory", fs.exists(GRAFANA_ALLOY_DATA_DIR)],
	];
	for (const [name, passed] of checks) {
		if (!passed) {
			log.error("Missing dependency: " + name);
			return false;
		}
	}

	const port = parseInt(httpPort(), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("GRAFANA_ALLOY_HTTP_LISTEN_ADDR has no valid port: " + GRAFANA_ALLOY_HTTP_LISTEN_ADDR);
		return false;
	}

	if (!fs.exists(GRAFANA_ALLOY_CONFIG)) {
		log.error("Alloy configuration file not found at " + GRAFANA_ALLOY_CONFIG);
		log.error("Mount your configuration there, or unset GRAFANA_ALLOY_CONFIG to use the bundled example.");
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
