// main.js — ezx bootstrap entrypoint for the Apache Kafka container.
//
// A behavioural port of the production Kafka container entrypoint
// (container-scripts/docker/apache-kafka), split into small modules mirroring
// the original bash init/ runtime structure:
//
//   entrypoint.sh        -> main() below
//   init/01-directories  -> directories.js (setupDirectories)
//   init/02-config       -> config.js (server.properties + log4j, generated here
//                           so storage formatting can consume it)
//   init/03-kraft        -> kraft.js (cluster id + storage format)
//   runtime/startup      -> runtime.js (chain.run supervision, flat DAG)
//   runtime/healthcheck  -> api.js (composite health on /health/comprehensive)
//   runtime/shutdown     -> orchestrator ShutdownConfig + ForwardSignals
//
// ezx stays PID 1 and supervises every node; it never exec's away. Config is
// generated and KRaft storage is formatted BEFORE the chain starts because
// kafka-storage.sh format requires the generated server.properties.
// Run:
//   ezx bootstrap /opt/container/entrypoint.d/bootstrap/main.js
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { validateEnvironment, validateDependencies } = require("./validation");
const { setupDirectories } = require("./directories");
const { prepareUserConfig, provisionConfig } = require("./config");
const { prepareStorage } = require("./kraft");
const { startDatabase, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);

	// Validate before any side effects.
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (!validateDependencies()) {
		throw new Error("Dependency validation failed");
	}

	setupDirectories();
	prepareUserConfig();
	provisionConfig();
	prepareStorage();

	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}

	registerOpsRoutes();
	startDatabase();
	log.info("Entrypoint complete");
}

main();
