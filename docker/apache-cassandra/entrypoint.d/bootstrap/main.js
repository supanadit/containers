// main.js — ezx bootstrap entrypoint for the Apache Cassandra container.
//
// A behavioural port of docker/apache-cassandra/entrypoint.sh, split into
// modules:
//
//   entrypoint.sh        -> main() below
//   JVM_OPTS export      -> runtime.js (node environment)
//   exec cassandra -f    -> runtime.js (supervised node; ezx stays PID 1)
//   (none)               -> config.js, validation.js, directories.js, api.js
//
// ezx stays PID 1 and supervises Cassandra; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { provisionConfig } = require("./config");
const { validateEnvironment } = require("./validation");
const { startCassandra, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);
	setupDirectories();
	if (!provisionConfig()) {
		throw new Error("Configuration setup failed");
	}
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}
	registerOpsRoutes();
	startCassandra();
	log.info("Entrypoint complete");
}

main();
