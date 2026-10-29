// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	GRAFANA_CONFIG_FILE,
	GRAFANA_DATA_DIR,
	GRAFANA_PORT,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	const checks = [
		["grafana", commandExists("grafana")],
		["data directory", fs.exists(GRAFANA_DATA_DIR)],
	];
	for (const [name, passed] of checks) {
		if (!passed) {
			log.error("Missing dependency: " + name);
			return false;
		}
	}

	// The port must be numeric — Grafana parses http_port.
	const port = parseInt(String(GRAFANA_PORT), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("GRAFANA_PORT is not a valid port: " + GRAFANA_PORT);
		return false;
	}

	// A missing config is not fatal: config.js seeds the bundled default before
	// this runs. If it is still absent, the user pointed GF_PATHS_CONFIG at a
	// path that does not exist.
	if (!fs.exists(GRAFANA_CONFIG_FILE)) {
		log.error("Grafana configuration file not found at " + GRAFANA_CONFIG_FILE);
		log.error("Mount your configuration there, or unset GF_PATHS_CONFIG to use the bundled default.");
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
