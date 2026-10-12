// directories.js — create and secure the container data/config/log/run
// directories and hand ownership to the airflow user.
const { fs, log } = require("ezx");
const {
	AIRFLOW_DATA_DIR,
	AIRFLOW_DAGS_DIR,
	AIRFLOW_CONFIG_DIR,
	AIRFLOW_LOG_DIR,
	AIRFLOW_RUN_DIR,
	AIRFLOW_BACKUP_DIR,
	AIRFLOW_PLUGINS_DIR,
	AIRFLOW_USER,
	AIRFLOW_GROUP,
} = require("./env");

const OWNER = AIRFLOW_USER + ":" + AIRFLOW_GROUP;

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
		AIRFLOW_DATA_DIR,
		AIRFLOW_DAGS_DIR,
		AIRFLOW_LOG_DIR,
		AIRFLOW_RUN_DIR,
		AIRFLOW_BACKUP_DIR,
		AIRFLOW_PLUGINS_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(AIRFLOW_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
