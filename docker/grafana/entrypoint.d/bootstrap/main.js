// main.js — ezx bootstrap entrypoint for the Grafana container.
//
// A behavioural port of docker/grafana/entrypoint.sh, split into modules:
//
//   entrypoint.sh        -> main() below
//   default config copy  -> config.js (seed bundled defaults.ini)
//   exec grafana server  -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// Order matters: the config file must be seeded before validation checks it.
// ezx stays PID 1 and supervises Grafana; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { seedDefaultConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startGrafana, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);

	setupDirectories();

	// Provision the config file before validating it (a bare docker run gets
	// the bundled default; a user-supplied path must already exist).
	seedDefaultConfig();

	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}

	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}

	// Register operator routes before chain.run (which blocks the script).
	registerOpsRoutes();
	startGrafana();
	log.info("Entrypoint complete");
}

main();
