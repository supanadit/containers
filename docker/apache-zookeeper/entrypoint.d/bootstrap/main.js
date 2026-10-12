// main.js — ezx bootstrap entrypoint for the Apache ZooKeeper container.
//
// A behavioural port of docker/apache-zookeeper/entrypoint.d/entrypoint.sh,
// split into modules:
//
//   entrypoint.sh        -> main() below
//   default zoo.cfg copy -> config.js (seed bundled/regenerated config)
//   exec zkServer.sh ... -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises ZooKeeper; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { seedDefaultConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startZookeeper, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);
	setupDirectories();
	seedDefaultConfig();
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}
	registerOpsRoutes();
	startZookeeper();
	log.info("Entrypoint complete");
}

main();
