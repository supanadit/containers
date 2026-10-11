// directories.js — create and secure the container data/config/log/run/backup
// directories and hand ownership to the minio user. The Dockerfile also
// pre-creates them (they must exist while /opt is root-owned); this makes the
// bootstrap idempotent and covers a bind-mounted volume with wrong ownership.
const { fs, log } = require("ezx");
const {
	MINIO_DATA_DIR,
	MINIO_CONFIG_DIR,
	MINIO_LOG_DIR,
	MINIO_RUN_DIR,
	MINIO_BACKUP_DIR,
	MINIO_USER,
	MINIO_GROUP,
	MINIO_ADDRESS,
	MINIO_CONSOLE_ADDRESS,
	MINIO_BROWSER_REDIRECT_URL,
	MINIO_DISTRIBUTED_MODE_ENABLED,
} = require("./env");

const OWNER = MINIO_USER + ":" + MINIO_GROUP;

// ensureDrive — MinIO requires every drive to be an existing directory when it
// starts (it will not create it). A drive may be given as a brace expansion
// ("data/disk{1...4}") or a plain path.
function ensureDrive(path) {
	const brace = /^(.*)\{(\d+)\.\.\.(\d+)\}$/.exec(path);
	if (brace) {
		const [, prefix, fromS, toS] = brace;
		const from = parseInt(fromS, 10);
		const to = parseInt(toS, 10);
		for (let i = from; i <= to; i++) {
			const p = prefix + i;
			fs.ensureDir(p, { mode: 0o750, owner: OWNER });
			fs.chmod(p, 0o750);
			fs.chownRecursive(p, OWNER);
		}
		return;
	}
	fs.ensureDir(path, { mode: 0o750, owner: OWNER });
	fs.chmod(path, 0o750);
	fs.chownRecursive(path, OWNER);
}

// setupDirectories — the normalized tree plus the drive directories.
function setupDirectories() {
	for (const d of [MINIO_DATA_DIR, MINIO_CONFIG_DIR, MINIO_LOG_DIR, MINIO_RUN_DIR, MINIO_BACKUP_DIR]) {
		fs.ensureDir(d, { mode: 0o750, owner: OWNER });
		fs.chmod(d, 0o750);
		fs.chownRecursive(d, OWNER);
	}

	// In distributed mode the drives live inside every node's expansion (e.g.
	// /data{1...4}), which is part of the node string and mounted by the
	// operator — nothing to create here. In standalone mode MinIO is given the
	// data directory as its single drive, so make sure it exists.
	if (!MINIO_DISTRIBUTED_MODE_ENABLED) {
		ensureDrive(MINIO_DATA_DIR);
	}

	if (MINIO_CONSOLE_ADDRESS) {
		log.info("Console listener: " + MINIO_CONSOLE_ADDRESS);
	}
	if (MINIO_BROWSER_REDIRECT_URL) {
		log.info("Browser redirect URL: " + MINIO_BROWSER_REDIRECT_URL);
	}
	log.info("API listener: " + MINIO_ADDRESS);
}

module.exports = { setupDirectories, ensureDrive };
