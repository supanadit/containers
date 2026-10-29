// main.js — ezx bootstrap entrypoint for the etcd container.
//
// A behavioural port of docker/etcd/entrypoint.sh, split into modules:
//
//   entrypoint.sh        -> main() below
//   data dir creation    -> directories.js
//   start_etcd()         -> runtime.js (argument matrix + supervised node)
//   exec etcd ...        -> runtime.js (supervised node; ezx stays PID 1)
//   health               -> api.js
//
// The bash entrypoint exec'd any non-etcd first argument (e.g. `docker run
// etcd-image etcdctl ...`). ezx bootstrap owns the entrypoint, so an arbitrary
// command cannot be exec'd from this script; use `ezx run` semantics or set a
// command via the orchestrator if that behaviour is needed. The default etcd
// path is preserved exactly.
//
// ezx stays PID 1 and supervises etcd; the container authors no shell.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { setupDirectories } = require("./directories");
const { validateEnvironment } = require("./validation");
const { startEtcd, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
	fs.umask(0o027);
	setupDirectories();
	if (!validateEnvironment()) {
		throw new Error("Environment validation failed");
	}
	if (SLEEP_MODE) {
		log.info("Sleep mode");
		startSleep();
		return;
	}
	registerOpsRoutes();
	startEtcd();
	log.info("Entrypoint complete");
}

main();
