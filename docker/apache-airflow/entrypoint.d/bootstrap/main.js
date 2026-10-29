// main.js — ezx bootstrap entrypoint for the Apache Airflow container.
//
// A behavioural port of docker/apache-airflow/entrypoint.sh, split into modules:
//
//   entrypoint.sh        -> main() below
//   `airflow db migrate` -> runtime.js (oneshot gate before the API server)
//   `airflow api-server` -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> config.js, validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises Airflow; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { seedDefaultConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startAirflow, startSleep } = require("./runtime");
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
	startAirflow();
	log.info("Entrypoint complete");
}

main();
