// config.js — configuration provisioning for the Prometheus container.
//
// Prometheus requires a --config.file. When the user mounts one, it is used
// unchanged. When the path is the container default and nothing is mounted, the
// bundled default config (installed by forge from the release tarball) is copied
// into place so a bare `docker run` works. An explicitly-set path that does not
// exist is left alone and reported by validation.js — the container never
// invents a config at a path the user chose.
const { fs, log } = require("ezx");
const {
	PROMETHEUS_CONFIG_FILE,
	PROMETHEUS_CONFIG_DIR,
	PROMETHEUS_DEFAULT_CONFIG,
	PROMETHEUS_USER,
	PROMETHEUS_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = PROMETHEUS_CONFIG_DIR + "/prometheus.yml";
const OWNER = PROMETHEUS_USER + ":" + PROMETHEUS_GROUP;

// isDefaultPath — the user did not point PROMETHEUS_CONFIG_FILE somewhere else.
function isDefaultPath() {
	return PROMETHEUS_CONFIG_FILE === DEFAULT_CONFIG_PATH;
}

// seedDefaultConfig — copy the bundled default config into place when the user
// relies on the container default and no config is mounted. Returns true when a
// config file is present afterwards.
function seedDefaultConfig() {
	if (fs.exists(PROMETHEUS_CONFIG_FILE)) {
		log.info("Using existing Prometheus configuration: " + PROMETHEUS_CONFIG_FILE);
		return true;
	}
	if (!isDefaultPath()) {
		// A user-chosen path must be mounted; do not fabricate it.
		return false;
	}
	if (!fs.exists(PROMETHEUS_DEFAULT_CONFIG)) {
		log.error("Bundled default config is missing: " + PROMETHEUS_DEFAULT_CONFIG);
		return false;
	}
	// fs.copy only takes overwrite/dereference/preserve-owner options; the mode
	// and ownership are applied explicitly afterwards.
	fs.copy(PROMETHEUS_DEFAULT_CONFIG, PROMETHEUS_CONFIG_FILE);
	fs.chmod(PROMETHEUS_CONFIG_FILE, 0o640);
	fs.chown(PROMETHEUS_CONFIG_FILE, OWNER);
	log.info("Seeded default Prometheus configuration at " + PROMETHEUS_CONFIG_FILE);
	return true;
}

module.exports = {
	seedDefaultConfig,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
