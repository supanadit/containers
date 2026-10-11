// runtime.js — supervise Apache httpd, the apache_exporter sidecar and sleep
// mode. ezx stays PID 1: it forwards signals, reaps zombies, rotates the logs
// and probes readiness. Nothing is exec'd away so the exporter can be drained
// alongside Apache.
const { chain, log } = require("ezx");
const {
  APACHE_HTPASSWD,
  APACHE_ROOT,
  APACHE_PORT,
  APACHE_USER,
  APACHE_GROUP,
  APACHE_EXPORTER,
  APACHE_EXPORTER_PORT,
  APACHE_STATUS,
  APACHE_LOG_DIR,
  APACHE_READY_MAX_ATTEMPTS,
  APACHE_READY_ATTEMPT_INTERVAL,
} = require("./env");

// apacheLog — per-service rotated log (50 MiB x 5).
function serviceLog(name) {
  return {
    stdout: "file",
    stderr: "file",
    filePath: APACHE_LOG_DIR + "/" + name + ".log",
    maxBytes: 50 * 1024 * 1024,
    maxBackups: 5,
  };
}

// apacheNode — the supervised httpd. Runs as root so it can bind port 80 and
// drop to www-data for its children (the httpd.conf User/Group directives); the
// WordPress workers still run as www-data.
function apacheNode() {
  return {
    name: "apache",
    process: {
      binaryPath: APACHE_HTPASSWD,
      arguments: ["-D", "FOREGROUND"],
      user: APACHE_USER,
      group: APACHE_GROUP,
      log: serviceLog("apache"),
    },
    readiness: {
      type: "tcp",
      tcp: { host: "127.0.0.1", port: Number(APACHE_PORT) },
      interval: APACHE_READY_ATTEMPT_INTERVAL * 1e9,
      timeout: 5e9,
      maxAttempts: APACHE_READY_MAX_ATTEMPTS,
    },
    forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP", "SIGWINCH"],
    // Apache honors the default drain signal (SIGTERM) as a graceful stop.
    shutdown: { timeout: 60e9, forceKill: true },
    restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
  };
}

// exporterNode — the apache_exporter sidecar. Non-fatal: it depends on Apache's
// readiness and its failure must not take WordPress down.
function exporterNode() {
  return {
    name: "apache-exporter",
    dependsOn: ["apache"],
    needParentReady: true,
    optional: true,
    process: {
      binaryPath: "/usr/local/bin/apache_exporter",
      arguments: [
        "--scrape_uri=http://127.0.0.1:" + APACHE_PORT + "/server-status?auto",
        "--web.listen-address=:" + APACHE_EXPORTER_PORT,
      ],
      log: serviceLog("apache-exporter"),
    },
    forwardSignals: ["SIGTERM", "SIGINT"],
    restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
  };
}

function startApache() {
  const nodes = [apacheNode()];
  if (APACHE_EXPORTER && APACHE_STATUS) {
    nodes.push(exporterNode());
  }
  chain.run({ nodes });
  log.info("Apache supervision started");
}

// startSleep — hold the container open without starting Apache.
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

module.exports = {
  startApache,
  startSleep,
  apacheNode,
  exporterNode,
  serviceLog,
};
