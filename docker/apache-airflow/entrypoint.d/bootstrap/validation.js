// validation.js — environment validation.
const { fs, log } = require("ezx");
const { AIRFLOW_API_SERVER, AIRFLOW_CONFIG_FILE, AIRFLOW_PORT } = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	if (!commandExists("airflow")) {
		log.error("Missing dependency: airflow");
		return false;
	}
	if (!fs.exists(AIRFLOW_API_SERVER)) {
		log.error("airflow binary not found at " + AIRFLOW_API_SERVER);
		return false;
	}
	const port = parseInt(String(AIRFLOW_PORT), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("AIRFLOW_PORT is not a valid port: " + AIRFLOW_PORT);
		return false;
	}
	// The config is seeded by config.js before this runs.
	if (!fs.exists(AIRFLOW_CONFIG_FILE)) {
		log.error("Airflow configuration file not found at " + AIRFLOW_CONFIG_FILE);
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
