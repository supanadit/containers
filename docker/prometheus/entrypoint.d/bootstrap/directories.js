// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the prometheus user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs } = require("ezx");
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

function setupDirectories() {
	for (const d of [
		PROMETHEUS_DATA_DIR,
		PROMETHEUS_CONFIG_DIR,
		PROMETHEUS_LOG_DIR,
		PROMETHEUS_RUN_DIR,
		PROMETHEUS_BACKUP_DIR,
	]) {
		fs.ensureDir(d, { mode: 0o750, owner: OWNER });
		fs.chmod(d, 0o750);
		fs.chownRecursive(d, OWNER);
	}
}

module.exports = { setupDirectories };
