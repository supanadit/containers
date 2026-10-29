// main.js — ezx bootstrap entrypoint for the MariaDB MaxScale container.
//
// A behavioural port of docker/maxscale/entrypoint.d/entrypoint.sh, split into
// modules:
//
//   entrypoint.sh        -> main() below
//   setup_directories    -> directories.js
//   generate_config      -> config.js (declarative INI from env)
//   validate_config      -> validation.js
//   wait_for_backends    -> removed: the supervised node starts immediately and
//                           MaxScale's own monitor retries; the bash wait loop
//                           could only delay startup and warn anyway.
//   exec maxscale ...    -> runtime.js (supervised node; ezx stays PID 1)
//
// ezx stays PID 1 and supervises MaxScale; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { generateConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startMaxScale, startSleep } = require("./runtime");
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
	startMaxScale();
	log.info("Entrypoint complete");
}

main();
