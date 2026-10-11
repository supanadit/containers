// main.js — ezx bootstrap entrypoint for the Thanos container.
//
// A behavioural port of docker/thanos/entrypoint.sh (one image, seven
// components), split into small modules:
//
//   entrypoint.sh        -> main() below
//   generate_s3_config   -> config.js (ezx.yaml, written 0600 to the config volume)
//   argument matrix      -> runtime.js (declarative process.argOperations)
//   exec thanos ...      -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises the component: it forwards SIGTERM/SIGINT/
// SIGHUP, reaps zombies, rotates the log and probes readiness. Thanos is never
// exec'd away, and the container authors no shell scripts.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { validateEnvironment } = require("./validation");
const { setupDirectories } = require("./directories");
const { startThanos, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);

	// Validate before any side effects.
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}

	setupDirectories();

	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}

	// Register operator routes before chain.run (which blocks the script).
	registerOpsRoutes();
	startThanos();
	log.info("Entrypoint complete");
}

main();
