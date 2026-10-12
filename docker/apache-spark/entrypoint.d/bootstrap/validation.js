// validation.js — environment validation.
const { fs, log } = require("ezx");
const { SPARK_CONFIG_DIR, SPARK_MASTER_PORT, SPARK_MASTER_WEBUI_PORT } = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	for (const cmd of ["spark-submit", "start-master.sh", "start-worker.sh"]) {
		if (!commandExists(cmd)) {
			log.error("Missing dependency: " + cmd);
			return false;
		}
	}
	for (const [name, value] of [
		["SPARK_MASTER_PORT", SPARK_MASTER_PORT],
		["SPARK_MASTER_WEBUI_PORT", SPARK_MASTER_WEBUI_PORT],
	]) {
		const port = parseInt(String(value), 10);
		if (!Number.isInteger(port) || port < 1 || port > 65535) {
			log.error(name + " is not a valid port: " + value);
			return false;
		}
	}
	if (!fs.exists(SPARK_CONFIG_DIR)) {
		log.error("SPARK_CONFIG_DIR does not exist: " + SPARK_CONFIG_DIR);
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
