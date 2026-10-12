// directories.js — create and secure the container data/config/log directories
// and hand ownership to the maxscale user.
const { fs, log } = require("ezx");
const {
	MAXSCALE_DATA_DIR,
	MAXSCALE_CONFIG_DIR,
	MAXSCALE_LOG_DIR,
} = require("./env");

const OWNER = "maxscale:maxscale";

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
		MAXSCALE_DATA_DIR,
		MAXSCALE_CONFIG_DIR,
		MAXSCALE_LOG_DIR,
		"/etc/maxscale.cnf.d",
		"/var/log/maxscale",
		"/var/lib/maxscale",
	]) {
		fs.ensureDir(d, { mode: 0o750 });
		chmodBestEffort(d, 0o750);
		chownBestEffort(d);
	}
}

module.exports = { setupDirectories };
