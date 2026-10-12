// main.js — ezx bootstrap entrypoint for the Grafana Pyroscope container.
//
// A behavioural port of docker/grafana-pyroscope/entrypoint.sh, split into
// modules:
//
//   entrypoint.sh        -> main() below
//   argument matrix      -> runtime.js (per-component flag matrix)
//   exec pyroscope ...   -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises Pyroscope; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { validateEnvironment } = require("./validation");
const { startPyroscope, startSleep } = require("./runtime");
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
	registerOpsRoutes();
	startPyroscope();
	log.info("Entrypoint complete");
}

main();
