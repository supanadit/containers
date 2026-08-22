// directories.js — init/01-directories: create and secure the container
// data/config/log/run/backup directories and chown them to the postgres user
// (mirrors the bash init/01-directories.sh).
const { fs } = require("ezx");
const {
	PGDATA,
	PGCONFIG,
	PGLOG,
	PGRUN,
	PGBACKUP,
	PG_USER,
	PG_GROUP,
	PGBACKREST_ENABLE,
} = require("./env");

function createDirectories() {
	const owner = PG_USER + ":" + PG_GROUP;

	for (const d of [PGCONFIG, PGLOG, PGRUN]) {
		fs.mkdirAll(d, 0o755);
		fs.chmod(d, 0o755);
	}

	fs.mkdirAll(PGDATA, 0o700);
	fs.chmod(PGDATA, 0o700);

	if (PGBACKREST_ENABLE) {
		fs.mkdirAll(PGBACKUP, 0o750);
		fs.chmod(PGBACKUP, 0o750);
		for (const s of ["spool", "log", "lock"]) {
			fs.mkdirAll(PGBACKUP + "/" + s, 0o750);
			fs.chmod(PGBACKUP + "/" + s, 0o750);
		}
	}

	// Ownership: everything must be writable by the postgres process (bash
	// 01-directories.sh chowns -R postgres:postgres).
	for (const d of [PGDATA, PGCONFIG, PGLOG, PGRUN, PGBACKUP]) {
		if (fs.exists(d)) fs.chownRecursive(d, owner);
	}
}

module.exports = { createDirectories };