// config.js — generate zoo.cfg from the container defaults.
//
// A config the user mounted (or a zoo.cfg left in the config dir by a previous
// start) is used unchanged; otherwise one is rendered from the env defaults so
// dataDir lands inside the volume.
const { fs, editor, config, log } = require("ezx");
const {
	ZOOKEEPER_CONFIG_FILE,
	ZOOKEEPER_CONFIG_DIR,
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
	b.set(
		"admin.enableServer",
		ZOOKEEPER_ADMIN_ENABLE_SERVER ? "true" : "false",
	);
	// ezx owns 8080 for its health API, and ZooKeeper's admin server defaults to
	// 0.0.0.0:8080: enabling it on the default port makes QuorumPeerMain die with
	// BindException (exit 4). Move it when it is enabled.
	if (ZOOKEEPER_ADMIN_ENABLE_SERVER) {
		b.set("admin.serverPort", ZOOKEEPER_ADMIN_SERVER_PORT);
	}
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
	// Always render from env. Seeding from the bundled zoo_sample.cfg made the
	// container keep upstream's dataDir=/tmp/zookeeper (outside the volume) and
	// its admin server on :8080, which collides with ezx's health API.
	const content = zooCfg();
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
