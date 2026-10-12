// directories.js — create and secure the container data/config/log/run
// directories and hand ownership to the spark user.
const { fs, log } = require("ezx");
const {
	SPARK_DATA_DIR,
	SPARK_CONFIG_DIR,
	SPARK_LOG_DIR,
	SPARK_RUN_DIR,
	SPARK_BACKUP_DIR,
	SPARK_USER,
	SPARK_GROUP,
} = require("./env");

const OWNER = SPARK_USER + ":" + SPARK_GROUP;

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
	for (const d of [SPARK_DATA_DIR, SPARK_LOG_DIR, SPARK_RUN_DIR, SPARK_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(SPARK_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
