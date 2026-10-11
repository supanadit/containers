// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the thanos user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	THANOS_DATA_DIR,
	THANOS_CONFIG_DIR,
	THANOS_LOG_DIR,
	THANOS_RUN_DIR,
	THANOS_BACKUP_DIR,
	THANOS_USER,
	THANOS_GROUP,
} = require("./env");

const OWNER = THANOS_USER + ":" + THANOS_GROUP;

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
// legitimate setup; a hard failure here would abort the container before the
// app ever starts.
function chownBestEffort(path) {
	try {
		fs.chownRecursive(path, OWNER);
	} catch (e) {
		log.warn("could not chown " + path + " (read-only mount?): " + e.message);
	}
}

function setupDirectories() {
	for (const d of [THANOS_DATA_DIR, THANOS_CONFIG_DIR, THANOS_LOG_DIR, THANOS_RUN_DIR, THANOS_BACKUP_DIR]) {
		// No `owner` here: ensureDir's own chown is recursive and would walk into
		// a read-only config file; the guarded helper below does it instead.
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
}

module.exports = { setupDirectories };
