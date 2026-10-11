// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the kafka user.
//
// Mirrors the bash init/01-directories.sh, minus the recursive chmod -R 755 of
// the data directory: rewriting a large (possibly network-backed) data volume's
// modes on every boot is both slow and unnecessary. Only the directory itself
// is normalized; files keep the modes Kafka wrote.
const { fs, log } = require("ezx");
const {
	KAFKA_DATA_DIR,
	KAFKA_CONFIG_DIR,
	KAFKA_LOG_DIR,
	KAFKA_RUN_DIR,
	KAFKA_BACKUP_DIR,
	KAFKA_USER,
	KAFKA_GROUP,
} = require("./env");

const OWNER = KAFKA_USER + ":" + KAFKA_GROUP;

function setupDirectories() {
	for (const d of [KAFKA_LOG_DIR, KAFKA_RUN_DIR, KAFKA_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o755 });
		fs.chmod(d, 0o755);
	}

	// Data dir holds the commit log and metadata; restrict it.
	fs.ensureDir(KAFKA_DATA_DIR, { mode: 0o700 });
	fs.chmod(KAFKA_DATA_DIR, 0o700);

	// Container-owned trees can be chowned wholesale.
	fs.chownRecursive(KAFKA_LOG_DIR, OWNER);
	fs.chownRecursive(KAFKA_RUN_DIR, OWNER);
	fs.chownRecursive(KAFKA_BACKUP_DIR, OWNER);
	fs.chown(KAFKA_DATA_DIR, OWNER);

	// Config may contain user-provided (possibly read-only) mounts; tolerate
	// failures and only ensure the directory exists and is owned by kafka.
	try {
		fs.ensureDir(KAFKA_CONFIG_DIR, { mode: 0o755 });
		fs.chmod(KAFKA_CONFIG_DIR, 0o755);
		fs.chown(KAFKA_CONFIG_DIR, OWNER);
	} catch (e) {
		log.warn("config dir is not writable/chownable (read-only mount?): " + e.message);
	}
}

module.exports = { setupDirectories };
