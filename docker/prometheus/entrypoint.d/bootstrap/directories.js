// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the prometheus user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	PROMETHEUS_DATA_DIR,
	PROMETHEUS_CONFIG_DIR,
	PROMETHEUS_LOG_DIR,
	PROMETHEUS_RUN_DIR,
	PROMETHEUS_BACKUP_DIR,
	PROMETHEUS_USER,
	PROMETHEUS_GROUP,
} = require("./env");

const OWNER = PROMETHEUS_USER + ":" + PROMETHEUS_GROUP;

// chmodBestEffort — set directory mode, but do not fail when the path is a
// read-only bind mount.
function chmodBestEffort(path, mode) {
	try {
		fs.chmod(path, mode);
	} catch (e) {
		log.warn("could not chmod " + path + " (read-only mount?): " + e.message);
	}
}

// chownBestEffort changes ownership recursively but does not fail the bootstrap
// when it cannot. A read-only bind mount (e.g. a config file mounted :ro) is a
// legitimate setup, and the old bash entrypoint chowned with `|| true`. A hard
// failure here would abort the container before the app ever starts.
function chownBestEffort(path) {
	try {
		fs.chownRecursive(path, OWNER);
	} catch (e) {
		log.warn("could not chown " + path + " (read-only mount?): " + e.message);
	}
}

function setupDirectories() {
	for (const d of [
		PROMETHEUS_DATA_DIR,
		PROMETHEUS_CONFIG_DIR,
		PROMETHEUS_LOG_DIR,
		PROMETHEUS_RUN_DIR,
		PROMETHEUS_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
}

module.exports = { setupDirectories };
