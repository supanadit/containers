// config.js — configuration provisioning for the Alloy container.
//
// When the user mounts config.alloy it is used unchanged. When the path is the
// container default and nothing is mounted, the bundled example config
// (/etc/alloy/config.alloy) is copied into place so a bare docker run works.
// An explicitly-set path that does not exist is left alone and reported by
// validation.js — the container never invents a config at a path the user chose.
const { fs, log } = require("ezx");
const {
	GRAFANA_ALLOY_CONFIG,
	GRAFANA_ALLOY_CONFIG_DIR,
	GRAFANA_ALLOY_DEFAULT_CONFIG,
	GRAFANA_ALLOY_USER,
	GRAFANA_ALLOY_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = GRAFANA_ALLOY_CONFIG_DIR + "/config.alloy";
const OWNER = GRAFANA_ALLOY_USER + ":" + GRAFANA_ALLOY_GROUP;

// isDefaultPath — the user did not point GRAFANA_ALLOY_CONFIG somewhere else.
function isDefaultPath() {
	return GRAFANA_ALLOY_CONFIG === DEFAULT_CONFIG_PATH;
}

// seedDefaultConfig — copy the bundled example config into place when the user
// relies on the container default and no config is mounted.
function seedDefaultConfig() {
	if (fs.exists(GRAFANA_ALLOY_CONFIG)) {
		log.info("Using existing Alloy configuration: " + GRAFANA_ALLOY_CONFIG);
		return true;
	}
	if (!isDefaultPath()) return false;
	if (!fs.exists(GRAFANA_ALLOY_DEFAULT_CONFIG)) {
		log.error("Bundled example config is missing: " + GRAFANA_ALLOY_DEFAULT_CONFIG);
		return false;
	}
	fs.copy(GRAFANA_ALLOY_DEFAULT_CONFIG, GRAFANA_ALLOY_CONFIG);
	fs.chmod(GRAFANA_ALLOY_CONFIG, 0o640);
	try {
		fs.chown(GRAFANA_ALLOY_CONFIG, OWNER);
	} catch (e) {
		log.warn("could not chown config (read-only mount?): " + e.message);
	}
	log.info("Seeded example Alloy configuration at " + GRAFANA_ALLOY_CONFIG);
	return true;
}

module.exports = {
	seedDefaultConfig,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
