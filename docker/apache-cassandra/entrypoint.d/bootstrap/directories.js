// directories.js — create and secure the container data/config/log/run
// directories and hand ownership to the cassandra user.
const { fs, log } = require("ezx");
const {
	CASSANDRA_DATA_DIR,
	CASSANDRA_CONFIG_DIR,
	CASSANDRA_LOG_DIR,
	CASSANDRA_RUN_DIR,
	CASSANDRA_BACKUP_DIR,
	CASSANDRA_USER,
	CASSANDRA_GROUP,
} = require("./env");

const OWNER = CASSANDRA_USER + ":" + CASSANDRA_GROUP;

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
		CASSANDRA_DATA_DIR,
		CASSANDRA_DATA_DIR + "/commitlog",
		CASSANDRA_DATA_DIR + "/saved_caches",
		CASSANDRA_DATA_DIR + "/hints",
		CASSANDRA_LOG_DIR,
		CASSANDRA_RUN_DIR,
		CASSANDRA_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(CASSANDRA_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
