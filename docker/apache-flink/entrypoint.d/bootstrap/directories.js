// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the flink user.
const { fs, log } = require("ezx");
const {
	FLINK_DATA_DIR,
	FLINK_CONFIG_DIR,
	FLINK_LOG_DIR,
	FLINK_RUN_DIR,
	FLINK_BACKUP_DIR,
	FLINK_USER,
	FLINK_GROUP,
} = require("./env");

const OWNER = FLINK_USER + ":" + FLINK_GROUP;

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
	for (const d of [FLINK_DATA_DIR, FLINK_LOG_DIR, FLINK_RUN_DIR, FLINK_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(FLINK_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
