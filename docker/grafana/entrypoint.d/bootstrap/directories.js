// directories.js — create and secure the container data/config/log/run/plugins
// directories and hand ownership to the grafana user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	GRAFANA_DATA_DIR,
	GRAFANA_CONFIG_DIR,
	GRAFANA_LOG_DIR,
	GRAFANA_RUN_DIR,
	GRAFANA_BACKUP_DIR,
	GRAFANA_PLUGINS_DIR,
	GRAFANA_PROVISIONING_DIR,
	GRAFANA_USER,
	GRAFANA_GROUP,
} = require("./env");

const OWNER = GRAFANA_USER + ":" + GRAFANA_GROUP;

// chmodBestEffort — set directory mode, but do not fail when the path is a
// read-only bind mount.
function chmodBestEffort(path, mode) {
	try {
		fs.chmod(path, mode);
	} catch (e) {
		log.warn("could not chmod " + path + " (read-only mount?): " + e.message);
	}
}

// chownBestEffort changes ownership recursively but does not fail when it
// cannot. A read-only bind mount is a legitimate setup; a hard failure here
// would abort the container before Grafana ever starts.
function chownBestEffort(path) {
	try {
		fs.chownRecursive(path, OWNER);
	} catch (e) {
		log.warn("could not chown " + path + " (read-only mount?): " + e.message);
	}
}

function setupDirectories() {
	for (const d of [
		GRAFANA_DATA_DIR,
		GRAFANA_LOG_DIR,
		GRAFANA_RUN_DIR,
		GRAFANA_BACKUP_DIR,
		GRAFANA_PLUGINS_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}

	// Config and provisioning may be read-only mounts; only ensure they exist.
	for (const d of [GRAFANA_CONFIG_DIR, GRAFANA_PROVISIONING_DIR]) {
		try {
			fs.ensureDir(d, { mode: 0o755 });
		} catch (e) {
			log.warn("could not create " + d + " (read-only mount?): " + e.message);
		}
	}
}

module.exports = { setupDirectories };
