// config.js — generate zoo.cfg from the container defaults.
//
// The bash entrypoint copied the bundled /opt/zookeeper/conf/zoo.cfg into the
// config volume when no config was mounted. Because the bundled config points
// dataDir at /opt/containers/data, the container regenerates a config from the
// env defaults when the user relies on the container default; a mounted
// zoo.cfg is used unchanged.
const { fs, editor, config, log } = require("ezx");
const {
	ZOOKEEPER_CONFIG_FILE,
	ZOOKEEPER_CONFIG_DIR,
	ZOOKEEPER_DEFAULT_CONFIG,
	ZOOKEEPER_DATA_DIR,
	ZOOKEEPER_DATA_LOG_DIR,
	ZOOKEEPER_CLIENT_PORT,
	ZOOKEEPER_TICK_TIME,
	ZOOKEEPER_MAX_CLIENT_CNXNS,
	ZOOKEEPER_ADMIN_ENABLE_SERVER,
	ZOOKEEPER_USER,
	ZOOKEEPER_GROUP,
} = require("./env");

const DEFAULT_CONFIG_PATH = ZOOKEEPER_CONFIG_DIR + "/zoo.cfg";
const OWNER = ZOOKEEPER_USER + ":" + ZOOKEEPER_GROUP;

// isDefaultPath — the user did not point ZOOCFGDIR somewhere else.
function isDefaultPath() {
	return ZOOKEEPER_CONFIG_FILE === DEFAULT_CONFIG_PATH;
}

// zooCfg — the generated zoo.cfg content.
function zooCfg() {
	const b = config.builder({ separator: "=", valueFormat: "none" });
	b.set("tickTime", ZOOKEEPER_TICK_TIME);
	b.set("dataDir", ZOOKEEPER_DATA_DIR);
	b.set("clientPort", ZOOKEEPER_CLIENT_PORT);
	b.set("maxClientCnxns", ZOOKEEPER_MAX_CLIENT_CNXNS);
	b.set("admin.enableServer", ZOOKEEPER_ADMIN_ENABLE_SERVER ? "true" : "false");
	return b.build();
}

// seedDefaultConfig — ensure a zoo.cfg exists. A mounted config wins; otherwise
// generate one from the env defaults so a bare docker run works.
function seedDefaultConfig() {
	if (fs.exists(ZOOKEEPER_CONFIG_FILE)) {
		log.info("Using existing ZooKeeper configuration: " + ZOOKEEPER_CONFIG_FILE);
		return true;
	}
	if (!isDefaultPath()) return false;
	// Prefer the bundled default (which keeps upstream layout) if it exists;
	// otherwise generate from env so the normalized data dir is honoured.
	let content;
	if (fs.exists(ZOOKEEPER_DEFAULT_CONFIG)) {
		content = editor.open(ZOOKEEPER_DEFAULT_CONFIG).read();
	} else {
		content = zooCfg();
	}
	try {
		fs.write(ZOOKEEPER_CONFIG_FILE, content, { mode: 0o644 });
		fs.chown(ZOOKEEPER_CONFIG_FILE, OWNER);
		fs.chmod(ZOOKEEPER_CONFIG_FILE, 0o644);
	} catch (e) {
		log.error("Cannot write " + ZOOKEEPER_CONFIG_FILE + ": " + e.message);
		return false;
	}
	log.info("Seeded ZooKeeper configuration at " + ZOOKEEPER_CONFIG_FILE);
	return true;
}

module.exports = {
	seedDefaultConfig,
	zooCfg,
	isDefaultPath,
	DEFAULT_CONFIG_PATH,
	OWNER,
};
