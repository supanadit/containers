// directories.js — init/01-directories: create and secure the container
// data/config/log/run/backup directories and chown them to the mysql user
// (mirrors the bash init/01-directories.sh).
const { fs } = require("ezx");
const {
	MARIADB_DATA_DIR,
	MARIADB_CONFIG_DIR,
	MARIADB_LOG_DIR,
	MARIADB_RUN_DIR,
	MARIADB_BACKUP_DIR,
	MARIADB_SSL_ENABLE,
	MARIADB_SSL_CERT_DIR,
} = require("./env");

const OWNER = "mysql:mysql";

function setupDirectories() {
	for (const d of [MARIADB_DATA_DIR, MARIADB_CONFIG_DIR, MARIADB_LOG_DIR, MARIADB_RUN_DIR, MARIADB_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o755 });
		fs.chmod(d, 0o755);
	}

	// Data dir must be writable by mysql for mariadb-install-db / mariadbd.
	fs.chownRecursive(MARIADB_DATA_DIR, OWNER);

	if (MARIADB_SSL_ENABLE) {
		fs.ensureDir(MARIADB_SSL_CERT_DIR, { mode: 0o700 });
		fs.chmod(MARIADB_SSL_CERT_DIR, 0o700);
		fs.chown(MARIADB_SSL_CERT_DIR, OWNER);
	}
}

module.exports = { setupDirectories };
