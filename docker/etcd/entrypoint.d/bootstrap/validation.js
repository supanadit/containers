// validation.js — environment validation.
const { fs, log } = require("ezx");
const {
	ETCD_DATA_DIR,
	ETCD_NAME,
	ETCD_LISTEN_PEER_URLS,
	ETCD_LISTEN_CLIENT_URLS,
	ETCD_INITIAL_CLUSTER_STATE,
	ETCD_CERT_FILE,
	ETCD_KEY_FILE,
	ETCD_TRUSTED_CA_FILE,
	ETCD_PEER_CERT_FILE,
	ETCD_PEER_KEY_FILE,
	ETCD_PEER_TRUSTED_CA_FILE,
} = require("./env");

// commandExists — resolve a binary on PATH without a shell.
function commandExists(name) {
	return fs.which(name);
}

// validateEnvironment — run every check and report the outcome.
function validateEnvironment() {
	if (!commandExists("etcd")) {
		log.error("Missing dependency: etcd");
		return false;
	}
	if (!ETCD_NAME) {
		log.error("ETCD_NAME must not be empty");
		return false;
	}
	if (!ETCD_LISTEN_PEER_URLS || !ETCD_LISTEN_CLIENT_URLS) {
		log.error("ETCD_LISTEN_PEER_URLS and ETCD_LISTEN_CLIENT_URLS must not be empty");
		return false;
	}
	if (!["new", "existing"].includes(String(ETCD_INITIAL_CLUSTER_STATE))) {
		log.error("Invalid ETCD_INITIAL_CLUSTER_STATE: " + ETCD_INITIAL_CLUSTER_STATE + " (must be new or existing)");
		return false;
	}

	// TLS files, when configured, must exist before start.
	for (const [name, path] of [
		["ETCD_CERT_FILE", ETCD_CERT_FILE],
		["ETCD_KEY_FILE", ETCD_KEY_FILE],
		["ETCD_TRUSTED_CA_FILE", ETCD_TRUSTED_CA_FILE],
		["ETCD_PEER_CERT_FILE", ETCD_PEER_CERT_FILE],
		["ETCD_PEER_KEY_FILE", ETCD_PEER_KEY_FILE],
		["ETCD_PEER_TRUSTED_CA_FILE", ETCD_PEER_TRUSTED_CA_FILE],
	]) {
		if (path && !fs.exists(path)) {
			log.error(name + " does not exist: " + path);
			return false;
		}
	}

	if (!fs.exists(ETCD_DATA_DIR)) {
		log.error("ETCD_DATA_DIR does not exist: " + ETCD_DATA_DIR);
		return false;
	}
	return true;
}

module.exports = {
	validateEnvironment,
	commandExists,
};
