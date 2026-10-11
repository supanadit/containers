// runtime.js — runtime/startup: run pgpool-II under ezx supervision. ezx stays
// PID 1, forwards signals, reaps zombies, and drains the graph on SIGTERM. This
// is ezx's only job here: pgpool-II keeps its native behaviour and its native
// hooks (follow_master_command / failover_command) are user-supplied paths.
//
// Run: ezx bootstrap /opt/container/entrypoint.d/bootstrap/main.js
const { chain } = require("ezx");
const {
  PGPOOL_PORT,
  PGPOOL_PID_FILE,
  PGPOOL_USER,
  PGPOOL_GROUP,
  PGPOOL_CONF,
  PGPOOL_LOG_DIR,
  PGPOOL_READY_MAX_ATTEMPTS,
} = require("./env");
const { pgpoolFiles } = require("./config");

// pgpoolLog — per-service rotated log (50 MiB x 5).
function pgpoolLog() {
  return {
    stdout: "file",
    stderr: "file",
    filePath: PGPOOL_LOG_DIR + "/pgpool.log",
    maxBytes: 50 * 1024 * 1024,
    maxBackups: 5,
  };
}

function startSleep() {
  chain.run({
    nodes: [
      {
        name: "sleep",
        process: {},
        restart: { mode: "always", backoff: 1e9 },
      },
    ],
  });
}

function startPgpool() {
  chain.run({
    nodes: [
      {
        name: "pgpool",
        files: pgpoolFiles(),
        process: {
          binaryPath: "pgpool",
          // -n: run in foreground (ezx supervises); -F: pid file; -f: pgpool.conf
          arguments: ["-f", PGPOOL_CONF, "-F", PGPOOL_PID_FILE, "-n"],
          user: PGPOOL_USER,
          group: PGPOOL_GROUP,
          log: pgpoolLog(),
        },
        readiness: {
          type: "tcp",
          tcp: { host: "127.0.0.1", port: Number(PGPOOL_PORT) },
          interval: 1e9,
          timeout: 5e9,
          maxAttempts: PGPOOL_READY_MAX_ATTEMPTS,
        },
        forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
        shutdown: { timeout: -1, forceKill: false },
      },
    ],
  });
}

module.exports = {
  startPgpool,
  startSleep,
};
