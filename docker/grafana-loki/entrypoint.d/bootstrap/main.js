// main.js — ezx bootstrap entrypoint for the Grafana Loki container.
//
// A behavioural port of docker/grafana-loki/entrypoint.d/entrypoint.sh, split
// into modules:
//
//   entrypoint.sh        -> main() below
//   init/configuration   -> config.js (declarative Loki YAML from env)
//   exec loki ...        -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises Loki; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { generateConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startLoki, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);
	setupDirectories();
	// Regenerate the config from env before validating it (Loki is env-driven).
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
	startLoki();
	log.info("Entrypoint complete");
}

main();
