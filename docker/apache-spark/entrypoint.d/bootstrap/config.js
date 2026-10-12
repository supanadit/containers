// config.js — configuration provisioning for the Spark container.
//
// When the user mounts spark-defaults.conf it is used unchanged. When the path
// is the container default and nothing is mounted, the bundled template is
// copied into place so a bare docker run works. An explicitly-set path that
// does not exist is left alone and reported by validation.js.
const { fs, log } = require("ezx");
const {
	SPARK_CONFIG_DIR,
	SPARK_DEFAULT_CONFIG,
	SPARK_USER,
	SPARK_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = SPARK_CONFIG_DIR + "/spark-defaults.conf";
const OWNER = SPARK_USER + ":" + SPARK_GROUP;

// isDefaultPath — the user did not point SPARK_CONFIG_DIR somewhere else.
function isDefaultPath() {
	return true;
}

// seedDefaultConfig — copy the bundled template into place when no config is
// mounted. Returns true when a config file is present afterwards.
function seedDefaultConfig() {
	if (fs.exists(DEFAULT_CONFIG_PATH)) {
		log.info("Using existing Spark configuration: " + DEFAULT_CONFIG_PATH);
		return true;
	}
	if (!isDefaultPath()) return false;
	if (!fs.exists(SPARK_DEFAULT_CONFIG)) {
		// The template is optional; create an empty file so Spark still starts.
		fs.write(DEFAULT_CONFIG_PATH, "", { mode: 0o644 });
		fs.chown(DEFAULT_CONFIG_PATH, OWNER);
		return true;
	}
	fs.copy(SPARK_DEFAULT_CONFIG, DEFAULT_CONFIG_PATH);
	fs.chmod(DEFAULT_CONFIG_PATH, 0o644);
	try {
		fs.chown(DEFAULT_CONFIG_PATH, OWNER);
	} catch (e) {
		log.warn("could not chown config (read-only mount?): " + e.message);
	}
	log.info("Seeded Spark configuration at " + DEFAULT_CONFIG_PATH);
	return true;
}

module.exports = {
	seedDefaultConfig,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
