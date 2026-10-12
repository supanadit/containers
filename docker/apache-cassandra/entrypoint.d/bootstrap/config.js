// config.js — validate and secure the Cassandra conf directory.
//
// The release's conf tree ships in the image with the repo's config/cassandra.yaml
// baked on top at build time (see the Dockerfile). This module only verifies the
// config is present and rewrites the storage paths to the normalized volume tree
// on first start, so a bare `docker run` does not write into the image.
const { fs, editor, log } = require("ezx");
const {
	CASSANDRA_CONFIG_FILE,
	CASSANDRA_DATA_DIR,
	CASSANDRA_USER,
	CASSANDRA_GROUP,
} = require("./env");

const OWNER = CASSANDRA_USER + ":" + CASSANDRA_GROUP;

// normalizeStoragePaths — rewrite the data/commitlog/cache paths in
// cassandra.yaml to the /opt/containers tree. Idempotent (a second start finds
// the paths already normalized).
function normalizeStoragePaths() {
	if (!fs.exists(CASSANDRA_CONFIG_FILE)) return false;
	let content = editor.open(CASSANDRA_CONFIG_FILE).read();
	const before = content;
	content = content
		.replace(/^data_file_directories:[\s\S]*?(?=^\S)/m, "data_file_directories:\n  - " + CASSANDRA_DATA_DIR + "\n")
		.replace(/^commitlog_directory:.*$/m, "commitlog_directory: " + CASSANDRA_DATA_DIR + "/commitlog")
		.replace(/^saved_caches_directory:.*$/m, "saved_caches_directory: " + CASSANDRA_DATA_DIR + "/saved_caches")
		.replace(/^hints_directory:.*$/m, "hints_directory: " + CASSANDRA_DATA_DIR + "/hints")
		.replace(/^cdc_raw_directory:.*$/m, "cdc_raw_directory: " + CASSANDRA_DATA_DIR + "/cdc_raw");
	if (content === before) return true;
	try {
		fs.write(CASSANDRA_CONFIG_FILE, content, { mode: 0o640 });
		fs.chown(CASSANDRA_CONFIG_FILE, OWNER);
		fs.chmod(CASSANDRA_CONFIG_FILE, 0o640);
		log.info("Normalized Cassandra storage paths in " + CASSANDRA_CONFIG_FILE);
	} catch (e) {
		// A read-only mount is legitimate; report and continue.
		log.warn("could not rewrite storage paths (read-only mount?): " + e.message);
	}
	return true;
}

// provisionConfig — verify the config exists and normalize its storage paths.
function provisionConfig() {
	if (!fs.exists(CASSANDRA_CONFIG_FILE)) {
		log.error("Cassandra configuration file not found at " + CASSANDRA_CONFIG_FILE);
		return false;
	}
	return normalizeStoragePaths();
}

module.exports = {
	provisionConfig,
	normalizeStoragePaths,
	OWNER,
};
