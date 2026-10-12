// config.js — configuration provisioning for the Airflow container.
//
// When the user mounts airflow.cfg it is used unchanged. When the path is the
// container default and nothing is mounted, the bundled config from the repo's
// config/ directory is copied into place so a bare docker run works.
const { fs, log } = require("ezx");
const {
	AIRFLOW_CONFIG_FILE,
	AIRFLOW_CONFIG_DIR,
	AIRFLOW_DEFAULT_CONFIG,
	AIRFLOW_USER,
	AIRFLOW_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = "/opt/airflow/airflow.cfg";
const OWNER = AIRFLOW_USER + ":" + AIRFLOW_GROUP;

// isDefaultPath — the user did not point AIRFLOW_CONFIG somewhere else.
function isDefaultPath() {
	return AIRFLOW_CONFIG_FILE === DEFAULT_CONFIG_PATH;
}

// seedDefaultConfig — copy the bundled default config into place when no config
// is mounted. Returns true when a config file is present afterwards.
function seedDefaultConfig() {
	if (fs.exists(AIRFLOW_CONFIG_FILE)) {
		log.info("Using existing Airflow configuration: " + AIRFLOW_CONFIG_FILE);
		return true;
	}
	if (!isDefaultPath()) return false;
	if (!fs.exists(AIRFLOW_DEFAULT_CONFIG)) {
		log.error("Bundled default config is missing: " + AIRFLOW_DEFAULT_CONFIG);
		return false;
	}
	try {
		fs.ensureDir(AIRFLOW_CONFIG_DIR, { mode: 0o755 });
		fs.copy(AIRFLOW_DEFAULT_CONFIG, AIRFLOW_CONFIG_FILE);
		fs.chmod(AIRFLOW_CONFIG_FILE, 0o640);
		fs.chown(AIRFLOW_CONFIG_FILE, OWNER);
	} catch (e) {
		log.warn("could not seed config (read-only mount?): " + e.message);
		return fs.exists(AIRFLOW_CONFIG_FILE);
	}
	log.info("Seeded default Airflow configuration at " + AIRFLOW_CONFIG_FILE);
	return true;
}

module.exports = {
	seedDefaultConfig,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
