// main.js — ezx bootstrap entrypoint for the Grafana Alloy container.
//
// A behavioural port of docker/grafana-alloy/entrypoint.sh, split into modules:
//
//   entrypoint.sh        -> main() below
//   config existence     -> config.js (seed bundled example) + validation.js
//   exec alloy run ...   -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> directories.js, api.js
//
// Order matters: the config file must be seeded before validation checks it.
// ezx stays PID 1 and supervises Alloy; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { seedDefaultConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startAlloy, startSleep } = require("./runtime");
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
	startAlloy();
	log.info("Entrypoint complete");
}

main();
