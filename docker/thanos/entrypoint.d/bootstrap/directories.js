// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the thanos user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs } = require("ezx");
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

function setupDirectories() {
	for (const d of [THANOS_DATA_DIR, THANOS_CONFIG_DIR, THANOS_LOG_DIR, THANOS_RUN_DIR, THANOS_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o750, owner: OWNER });
		fs.chmod(d, 0o750);
		fs.chownRecursive(d, OWNER);
	}
}

module.exports = { setupDirectories };
