// main.js — ezx bootstrap entrypoint for the PgPool-II container.
//
// Replaces the bash entrypoint.sh with a small module set:
//
//   entrypoint.sh        -> main() below
//   validate_environment -> validation.js
//   setup_directories    -> directories.js
//   generate_pgpool_conf -> config.js (provisionConfig)
//   generate_pool_hba    -> config.js
//   generate_pool_passwd -> config.js (native pg_md5, after pgpool.conf)
//   start_pgpool         -> runtime.js (chain.run supervision)
//   runtime/healthcheck  -> api.js (/health/comprehensive)
//   runtime/shutdown     -> orchestrator ShutdownConfig + ForwardSignals
//
// pgpool-II runs natively; ezx only supervises it (PID 1, signals, reaping,
// log rotation, readiness). The container authors no shell scripts: native
// pgpool hooks (follow_master_command / failover_command) are user-supplied
// paths set via env.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { validateEnvironment } = require("./validation");
const { setupDirectories } = require("./directories");
const { provisionConfig } = require("./config");
const { startSleep, startPgpool } = require("./runtime");
const { registerOpsRoutes } = require("./api");

function main() {
  fs.umask(0o027);

  // Validate the environment before any side effects (mirrors entrypoint.sh:
  // validate_environment).
  if (!validateEnvironment()) {
    throw new Error("Environment validation failed");
  }

  setupDirectories();

  // Write pgpool.conf / pool_hba.conf / pool_passwd before anything starts.
  // pg_md5 reads pgpool.conf to locate pool_passwd, so this ordering matters.
  provisionConfig();

  if (SLEEP_MODE) {
    log.info("Sleep mode");
    startSleep();
    return;
  }

  // Register operator routes before chain.run (which blocks the script).
  registerOpsRoutes();
  startPgpool();
  log.info("Entrypoint complete");
}

main();
