// main.js — ezx bootstrap entrypoint for the Apache Spark container.
//
// A behavioural port of docker/apache-spark/entrypoint.d/entrypoint.sh, split
// into modules:
//
//   entrypoint.sh        -> main() below
//   default config copy  -> config.js
//   master + worker      -> runtime.js (two supervised nodes; ezx stays PID 1)
//   tail -f keepalive    -> replaced by supervising both processes
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises both processes; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { seedDefaultConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startSpark, startSleep } = require("./runtime");
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
	startSpark();
	log.info("Entrypoint complete");
}

main();
