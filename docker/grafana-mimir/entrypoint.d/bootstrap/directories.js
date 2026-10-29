// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the mimir user. The Dockerfile also
// pre-creates them; this makes the bootstrap idempotent and covers a
// bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	GRAFANA_MIMIR_DATA_DIR,
	GRAFANA_MIMIR_CONFIG_DIR,
	GRAFANA_MIMIR_LOG_DIR,
	GRAFANA_MIMIR_RUN_DIR,
	GRAFANA_MIMIR_BACKUP_DIR,
	MIMIR_TSDB_DIR,
	GRAFANA_MIMIR_USER,
	GRAFANA_MIMIR_GROUP,
} = require("./env");

const OWNER = GRAFANA_MIMIR_USER + ":" + GRAFANA_MIMIR_GROUP;

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
		GRAFANA_MIMIR_DATA_DIR,
		MIMIR_TSDB_DIR,
		GRAFANA_MIMIR_LOG_DIR,
		GRAFANA_MIMIR_RUN_DIR,
		GRAFANA_MIMIR_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
	// The bash entrypoint also pre-created the per-component subdirectories
	// under /var/lib/mimir. Keep them for backwards compatibility.
	for (const d of ["/var/lib/mimir/tsdb", "/var/lib/mimir/tsdb-sync", "/var/lib/mimir/rules", "/var/lib/mimir/alertmanager", "/var/lib/mimir/compactor"]) {
		fs.ensureDir(d, { mode: 0o750 });
		chownBestEffort(d);
	}
	try {
		fs.ensureDir(GRAFANA_MIMIR_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
