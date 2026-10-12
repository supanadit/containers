// directories.js — create and secure the container data/config/log/run
// directories and hand ownership to the zookeeper user. The Dockerfile also
// pre-creates them; this makes the bootstrap idempotent and covers a
// bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	ZOOKEEPER_DATA_DIR,
	ZOOKEEPER_DATA_LOG_DIR,
	ZOOKEEPER_CONFIG_DIR,
	ZOOKEEPER_LOG_DIR,
	ZOOKEEPER_RUN_DIR,
	ZOOKEEPER_USER,
	ZOOKEEPER_GROUP,
} = require("./env");

const OWNER = ZOOKEEPER_USER + ":" + ZOOKEEPER_GROUP;

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
	for (const d of [ZOOKEEPER_DATA_DIR, ZOOKEEPER_DATA_LOG_DIR, ZOOKEEPER_LOG_DIR, ZOOKEEPER_RUN_DIR]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(ZOOKEEPER_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
