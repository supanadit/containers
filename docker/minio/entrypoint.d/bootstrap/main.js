// main.js — ezx bootstrap entrypoint for the MinIO container.
//
// A behavioural port of docker/minio/entrypoint.sh, split into modules:
//
//   entrypoint.sh        -> main() below
//   hostname -i redirect -> config.js (browserRedirectUrl)
//   data dir creation    -> directories.js (ensureDrive)
//   unset MINIO_*        -> config.js (filterEnvPatterns; ezx sets the child
//                           environment explicitly, so nothing leaks)
//   start_minio_*        -> runtime.js (supervised node; ezx stays PID 1)
//   runtime/healthcheck  -> api.js (composite health on /health/comprehensive)
//
// MinIO runs from Go source (no community binaries upstream), so the image is a
// build stage plus a slim runtime stage; the bootstrap itself is identical to the
// other containers. The arbitrary-command pass-through the bash script offered is
// intentionally dropped: with ezx as PID 1 the supported path for admin commands
// is `docker exec`.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { validateEnvironment } = require("./validation");
const { startMinio, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);

	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}

	setupDirectories();

	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}

	// Register operator routes before chain.run (which blocks the script).
	registerOpsRoutes();
	startMinio();
	log.info("Entrypoint complete");
}

main();
