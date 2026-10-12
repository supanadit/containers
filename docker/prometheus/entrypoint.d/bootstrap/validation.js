// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	PROMETHEUS_CONFIG_FILE,
	PROMETHEUS_WEB_CONFIG_FILE,
	PROMETHEUS_DATA_DIR,
	PROMETHEUS_CONFIG_DIR,
	PROMETHEUS_PORT,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateConfigFile — Prometheus cannot start without --config.file. A missing
// file is a hard error (the bash entrypoint exited 1); config.js seeds the
// bundled default when the path is exactly the container default, so this only
// fires for a user-supplied path that is genuinely absent.
function validateConfigFile() {
	if (!fs.exists(PROMETHEUS_CONFIG_FILE)) {
		log.error("Prometheus configuration file not found at " + PROMETHEUS_CONFIG_FILE);
		log.error("Mount your configuration there, or unset PROMETHEUS_CONFIG_FILE to use the bundled default.");
		return false;
	}
	return true;
}

// validateWebConfig — an explicitly requested web (TLS) config must exist.
function validateWebConfig() {
	if (!PROMETHEUS_WEB_CONFIG_FILE) return true;
	if (!fs.exists(PROMETHEUS_WEB_CONFIG_FILE)) {
		log.error("PROMETHEUS_WEB_CONFIG_FILE does not exist: " + PROMETHEUS_WEB_CONFIG_FILE);
		return false;
	}
	return true;
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	const checks = [
		["prometheus", commandExists("prometheus")],
		["promtool", commandExists("promtool")],
		["data directory", fs.exists(PROMETHEUS_DATA_DIR)],
		["config directory", fs.exists(PROMETHEUS_CONFIG_DIR)],
		["web config file", validateWebConfig()],
	];
	for (const [name, passed] of checks) {
		if (!passed) {
			log.error("Missing dependency: " + name);
			return false;
		}
	}

	// The port must be numeric — Prometheus parses --web.listen-address.
	const port = parseInt(String(PROMETHEUS_PORT), 10);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		log.error("PROMETHEUS_PORT is not a valid port: " + PROMETHEUS_PORT);
		return false;
	}

	return validateConfigFile();
}

module.exports = {
	validateEnvironment,
	validateConfigFile,
	validateWebConfig,
	commandExists,
};
