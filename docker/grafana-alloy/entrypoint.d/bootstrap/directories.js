// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the alloy user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	GRAFANA_ALLOY_DATA_DIR,
	GRAFANA_ALLOY_CONFIG_DIR,
	GRAFANA_ALLOY_LOG_DIR,
	GRAFANA_ALLOY_RUN_DIR,
	GRAFANA_ALLOY_BACKUP_DIR,
	GRAFANA_ALLOY_USER,
	GRAFANA_ALLOY_GROUP,
} = require("./env");

const OWNER = GRAFANA_ALLOY_USER + ":" + GRAFANA_ALLOY_GROUP;

// chmodBestEffort — set directory mode, but do not fail on a read-only mount.
function chmodBestEffort(path, mode) {
	try {
		fs.chmod(path, mode);
	} catch (e) {
		log.warn("could not chmod " + path + " (read-only mount?): " + e.message);
	}
}

// chownBestEffort changes ownership recursively but does not fail when it
// cannot. A read-only bind mount is a legitimate setup; a hard failure here
// would abort the container before Alloy ever starts.
function chownBestEffort(path) {
	try {
		fs.chownRecursive(path, OWNER);
	} catch (e) {
		log.warn("could not chown " + path + " (read-only mount?): " + e.message);
	}
}

function setupDirectories() {
	for (const d of [
		GRAFANA_ALLOY_DATA_DIR,
		GRAFANA_ALLOY_LOG_DIR,
		GRAFANA_ALLOY_RUN_DIR,
		GRAFANA_ALLOY_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	// Config may be a read-only mount; only ensure it exists.
	try {
		fs.ensureDir(GRAFANA_ALLOY_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
