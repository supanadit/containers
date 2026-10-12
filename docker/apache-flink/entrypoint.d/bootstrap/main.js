// main.js — ezx bootstrap entrypoint for the Apache Flink container.
//
// A behavioural port of docker/apache-flink/entrypoint.d/entrypoint.sh, split
// into modules:
//
//   entrypoint.sh        -> main() below
//   CONFIG_* -> yaml     -> config.js (flink-conf.yaml generation)
//   taskmanager + jobmanager -> runtime.js (two supervised nodes; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises both processes; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { generateConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startFlink, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);
	setupDirectories();
	generateConfig();
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}
	registerOpsRoutes();
	startFlink();
	log.info("Entrypoint complete");
}

main();
