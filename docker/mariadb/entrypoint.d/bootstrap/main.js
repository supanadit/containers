// main.js — ezx bootstrap entrypoint for the MariaDB container.
//
// A 1:1 behavioural port of the production MariaDB container entrypoint
// (container-scripts/docker/mariadb), split into small modules mirroring the
// bash init/ runtime structure:
//
//   entrypoint.sh        -> main() below
//   init/00-misc-scripts -> (handled by the reaper / process tree)
//   init/01-directories  -> setupDirectories() below
//   init/02-database     -> database.js (mariadb-install-db + bootstrap SQL)
//   init/03-config       -> config.js (declarative FileProvision)
//   runtime/startup      -> runtime.js (chain.run supervision, flat DAG)
//   runtime/healthcheck  -> api.js (composite health on /health/comprehensive)
//   runtime/shutdown     -> orchestrator ShutdownConfig + ForwardSignals
//   (reaper)             -> handled silently by ezx (PID 1 init)
//
// ezx stays PID 1 and supervises every node; it never exec's away. The
// mariadb node is the single supervised process. Each node has its own
// rotated log file under /opt/containers/logs/. Requires a mariadb image
// with mariadbd installed. Run:
//   ezx bootstrap /opt/container/entrypoint.d/bootstrap/main.js
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { initdb } = require("./database");
const { startSleep, startDatabase } = require("./runtime");
const { validateEnvironment, validateDependencies } = require("./validation");
const { registerOpsRoutes } = require("./api");
const { setupDirectories } = require("./directories");

function main() {
	fs.umask(0o027);

	// Validate environment and required dependencies before any side effects
	// (mirrors entrypoint.sh: validate_environment + validate_dependencies).
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (!validateDependencies()) {
		throw new Error("Dependency validation failed");
	}

	setupDirectories();
	initdb();

	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}

	// Register operator-facing routes (composite health) on the health server
	// before the chain starts supervising.
	registerOpsRoutes();
	startDatabase();
	log.info("Entrypoint complete");
}

main();
