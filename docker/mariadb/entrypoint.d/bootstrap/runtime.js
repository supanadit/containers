// runtime.js — MariaDB runtime supervisor
const { chain, scheduler } = require("ezx");
const { mariadbFiles } = require("./config");
const { runBackup } = require("./backup");
const {
  MARIADB_LOG_DIR,
  MARIADB_SOCKET,
  MARIADB_PID_FILE,
  MARIADB_CONFIG_FILE,
  MARIADB_ROOT_PASSWORD,
  MARIADB_SSL_ENABLE,
  MARIADB_SSL_CERT_DIR,
  MARIADB_BACKUP_ENABLE,
  MARIADB_BACKUP_SCHEDULE,
  MARIADB_BACKUP_INCR_SCHEDULE,
  MARIADB_BACKUP_TIMEZONE,
  MARIADB_READY_MAX_ATTEMPTS,
  MARIADB_READY_ATTEMPT_INTERVAL,
} = require("./env");

// Build mariadb-admin ping command for readiness probe
function buildPingArgs() {
  const args = ["mariadb-admin", "--socket=" + MARIADB_SOCKET, "-u", "root"];
  // Password comes from env.js (ezx.env) — there is no Node global `process`
  // in the goja runtime, so process.env would throw a ReferenceError here.
  if (MARIADB_ROOT_PASSWORD) {
    args.push("-p" + MARIADB_ROOT_PASSWORD);
  }
  // TLS must match what my.cnf configures (config.js): the 11.8 client
  // requires TLS by default, so against a server with ssl=0 the probe dies
  // with "SSL is required, but the server does not support it" and the node
  // never becomes ready (mariadbd is up, but the readiness gate fails).
  if (MARIADB_SSL_ENABLE) {
    args.push("--ssl-ca=" + MARIADB_SSL_CERT_DIR + "/ca.crt");
  } else {
    args.push("--skip-ssl");
  }
  args.push("ping");
  return args;
}

// startDatabase — supervise the MariaDB (and sidecar) process tree.
function startDatabase() {
  chain.run({ nodes: buildNodes() });
}

// backupNode — scheduled physical backup driven by a cron callback in JS (ezx
// scheduler.every), not a supervised process. One node per backup type, the
// pgBackRest pattern: a FULL node that starts a chain and an INCR node that
// extends the newest chain. Each tick self-gates on the mariadbd socket and on
// a lockfile (see backup.js), so an overlap is skipped rather than corrupting a
// chain. Gated on MARIADB_BACKUP_ENABLE; the incr node also needs a schedule.
function backupNode(nodeName, cron, type) {
  if (!MARIADB_BACKUP_ENABLE || !cron) return null;
  return {
    name: nodeName,
    dependsOnEdges: [{ name: "mariadb", waitFor: "ready" }],
    optional: true,
    scheduler: scheduler.every(cron, () => runBackup(type), {
      timezone: MARIADB_BACKUP_TIMEZONE,
      initialDelay: 60e9,
    }),
  };
}

// buildNodes — flat DAG: every node is a sibling; dependents express "wait for
// mariadb to be ready" via dependsOnEdges.
function buildNodes() {
  const nodes = [
    {
      name: "mariadb",
      process: {
        binaryPath: "mariadbd",
        arguments: [
          "--defaults-file=" + MARIADB_CONFIG_FILE,
          "--socket=" + MARIADB_SOCKET,
          "--pid-file=" + MARIADB_PID_FILE,
          "--user=mysql",
        ],
        user: "mysql",
        group: "mysql",
        log: {
          stdout: "file",
          stderr: "file",
          filePath: MARIADB_LOG_DIR + "/mariadb.log",
          maxBytes: 50 * 1024 * 1024,
          maxBackups: 5,
        },
      },
      readiness: {
        type: "exec",
        exec: buildPingArgs(),
        // ezx durations are NANOSECONDS (see postgresql's runtime.js:
        // interval 1e9, timeout 5e9). Passing milliseconds killed every probe
        // attempt instantly ("readiness probe error: signal: killed") and the
        // node never became ready even though mariadbd was serving.
        interval: parseInt(MARIADB_READY_ATTEMPT_INTERVAL, 10) * 1e9,
        timeout: 5e9,
        maxAttempts: parseInt(MARIADB_READY_MAX_ATTEMPTS, 10),
      },
      // Generate MARIADB_CONFIG_FILE (my.cnf) before the process starts — the
      // node is launched with --defaults-file, so an unprovisioned config file
      // aborts mariadbd with "Could not open required defaults file".
      files: mariadbFiles(),
      restart: {
        mode: "on-failure",
        maxRetries: 3,
      },
    },
  ];
  for (const n of [
    backupNode("mariadb-backup-full", MARIADB_BACKUP_SCHEDULE, "full"),
    backupNode("mariadb-backup-incr", MARIADB_BACKUP_INCR_SCHEDULE, "incr"),
  ]) {
    if (n) nodes.push(n);
  }
  return nodes;
}

// Sleep mode (SLEEP_MODE=true): hold the container open without starting
// mariadbd, for testing the health API and entrypoint wiring. A callback-only
// node (no binary) that never exits; mirrors postgresql's runtime.js.
function startSleep() {
  chain.run({
    nodes: [
      {
        name: "sleep",
        process: {},
        restart: { mode: "always", backoff: 1000 * 1e6 },
      },
    ],
  });
}

module.exports = {
  startDatabase,
  startSleep,
  buildPingArgs,
  buildNodes,
  backupNode,
};
