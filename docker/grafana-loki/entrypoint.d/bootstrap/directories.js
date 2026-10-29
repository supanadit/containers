// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the loki user.
const { fs, log } = require("ezx");
const {
	GRAFANA_LOKI_DATA_DIR,
	GRAFANA_LOKI_CONFIG_DIR,
	GRAFANA_LOKI_LOG_DIR,
	GRAFANA_LOKI_RUN_DIR,
	GRAFANA_LOKI_BACKUP_DIR,
	GRAFANA_LOKI_USER,
	GRAFANA_LOKI_GROUP,
} = require("./env");

const OWNER = GRAFANA_LOKI_USER + ":" + GRAFANA_LOKI_GROUP;

function chmodBestEffort(path, mode) {
	try {
		fs.chmod(path, mode);
	} catch (e) {
		log.warn("could not chmod " + path + " (read-only mount?): " + e.message);
	}
}

function chownBestEffort(path) {
	try {
		fs.chownRecursive(path, OWNER);
	} catch (e) {
		log.warn("could not chown " + path + " (read-only mount?): " + e.message);
	}
}

function setupDirectories() {
	for (const d of [
		GRAFANA_LOKI_DATA_DIR,
		GRAFANA_LOKI_LOG_DIR,
		GRAFANA_LOKI_RUN_DIR,
		GRAFANA_LOKI_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(GRAFANA_LOKI_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
