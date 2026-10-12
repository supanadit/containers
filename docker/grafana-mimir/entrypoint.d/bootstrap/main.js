// main.js — ezx bootstrap entrypoint for the Grafana Mimir container.
//
// A behavioural port of docker/grafana-mimir/entrypoint.d/entrypoint.sh, split
// into modules:
//
//   entrypoint.sh        -> main() below
//   init/configuration   -> config.js (declarative Mimir YAML from env)
//   exec mimir ...       -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises Mimir; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { generateConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startMimir, startSleep } = require("./runtime");
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
	startMimir();
	log.info("Entrypoint complete");
}

main();
