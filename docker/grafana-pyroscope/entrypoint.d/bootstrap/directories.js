// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the pyroscope user.
const { fs, log } = require("ezx");
const {
	PYROSCOPE_DATA_DIR,
	PYROSCOPE_CONFIG_DIR,
	PYROSCOPE_LOG_DIR,
	PYROSCOPE_RUN_DIR,
	PYROSCOPE_BACKUP_DIR,
	PYROSCOPE_USER,
	PYROSCOPE_GROUP,
} = require("./env");

const OWNER = PYROSCOPE_USER + ":" + PYROSCOPE_GROUP;

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
		PYROSCOPE_DATA_DIR,
		PYROSCOPE_LOG_DIR,
		PYROSCOPE_RUN_DIR,
		PYROSCOPE_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(PYROSCOPE_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
