// config.js — configuration provisioning for the Grafana container.
//
// When the user mounts grafana.ini it is used unchanged. When the path is the
// container default and nothing is mounted, the bundled default config
// (.../conf/defaults.ini) is copied into place so a bare docker run works. An
// explicitly-set path that does not exist is left alone and reported by
// validation.js — the container never invents a config at a path the user chose.
const { fs, log } = require("ezx");
const {
	GRAFANA_CONFIG_FILE,
	GRAFANA_CONFIG_DIR,
	GRAFANA_DEFAULT_CONFIG,
	GRAFANA_USER,
	GRAFANA_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = GRAFANA_CONFIG_DIR + "/grafana.ini";
const OWNER = GRAFANA_USER + ":" + GRAFANA_GROUP;

// isDefaultPath — the user did not point GF_PATHS_CONFIG somewhere else.
function isDefaultPath() {
	return GRAFANA_CONFIG_FILE === DEFAULT_CONFIG_PATH;
}

// seedDefaultConfig — copy the bundled default config into place when the user
// relies on the container default and no config is mounted. Returns true when a
// config file is present afterwards.
function seedDefaultConfig() {
	if (fs.exists(GRAFANA_CONFIG_FILE)) {
		log.info("Using existing Grafana configuration: " + GRAFANA_CONFIG_FILE);
		return true;
	}
	if (!isDefaultPath()) {
		// A user-chosen path must be mounted; do not fabricate it.
		return false;
	}
	if (!fs.exists(GRAFANA_DEFAULT_CONFIG)) {
		log.error("Bundled default config is missing: " + GRAFANA_DEFAULT_CONFIG);
		return false;
	}
	fs.copy(GRAFANA_DEFAULT_CONFIG, GRAFANA_CONFIG_FILE);
	fs.chmod(GRAFANA_CONFIG_FILE, 0o640);
	try {
		fs.chown(GRAFANA_CONFIG_FILE, OWNER);
	} catch (e) {
		log.warn("could not chown config (read-only mount?): " + e.message);
	}
	log.info("Seeded default Grafana configuration at " + GRAFANA_CONFIG_FILE);
	return true;
}

module.exports = {
	seedDefaultConfig,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
