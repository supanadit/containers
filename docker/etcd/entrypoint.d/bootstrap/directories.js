// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the etcd user. The Dockerfile also
// pre-creates them; this makes the bootstrap idempotent.
//
// The data directory is forced to mode 0700, matching the bash entrypoint
// (chmod 700 "$ETCD_DATA_DIR").
const { fs, log } = require("ezx");
const {
	ETCD_DATA_DIR,
	ETCD_CONFIG_DIR,
	ETCD_LOG_DIR,
	ETCD_RUN_DIR,
	ETCD_BACKUP_DIR,
	ETCD_USER,
	ETCD_GROUP,
} = require("./env");

const OWNER = ETCD_USER + ":" + ETCD_GROUP;

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
	// Data dir holds the WAL and snapshots; restrict it.
	fs.ensureDir(ETCD_DATA_DIR, { mode: 0o700 });
	chmodBestEffort(ETCD_DATA_DIR, 0o700);
	chownBestEffort(ETCD_DATA_DIR);

	for (const d of [ETCD_LOG_DIR, ETCD_RUN_DIR, ETCD_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}

	// Config may contain read-only mounts; only ensure it exists.
	try {
		fs.ensureDir(ETCD_CONFIG_DIR, { mode: 0o755 });
	} catch (e) {
		log.warn("could not create config dir (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
