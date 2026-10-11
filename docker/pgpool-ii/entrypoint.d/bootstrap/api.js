// api.js — operator-facing routes on the shared ezx health server
// (EZX_HEALTH_ADDR). Registered BEFORE chain.run; handlers run on HTTP
// goroutines while the chain supervises.
//
// This route is an operator detail view only. Container health is driven by
// ezx's built-in /readyz, which returns HTTP 503 while the node's readyProbe
// (a real `SELECT 1` through pgpool — see runtime.js) is failing. A script route
// cannot carry that signal: ezx.api always answers HTTP 200, whatever the body.
const { api, probe, process } = require("ezx");
const {
  PGPOOL_PORT,
  PGPOOL_HEALTH_CHECK_USER,
  PGPOOL_HEALTH_CHECK_PASSWORD,
  PGPOOL_HEALTH_CHECK_DATABASE,
} = require("./env");

// checkPgpool — the listener accepts connections.
function checkPgpool() {
  return probe.tcp("127.0.0.1", Number(PGPOOL_PORT));
}

// checkBackendAuth — pgpool can actually reach and authenticate to a backend.
//
// The TCP check alone is not health: pgpool happily accepts client connections
// while failing every query with "failed to authenticate with backend using
// SCRAM" (a pool_passwd that cannot hold a recoverable password). This runs a
// real query through pgpool so the detail view cannot read green while broken.
function checkBackendAuth() {
  if (!PGPOOL_HEALTH_CHECK_PASSWORD) {
    return false;
  }
  try {
    const res = process.capture({
      process: {
        binaryPath: "psql",
        arguments: [
          "-h",
          "127.0.0.1",
          "-p",
          String(PGPOOL_PORT),
          "-U",
          PGPOOL_HEALTH_CHECK_USER,
          "-d",
          PGPOOL_HEALTH_CHECK_DATABASE,
          "-tAc",
          "SELECT 1",
        ],
        // PGPASSWORD goes through the environment, never argv, so the secret
        // stays out of the process list.
        environment: ["PGPASSWORD=" + PGPOOL_HEALTH_CHECK_PASSWORD],
      },
    });
    return res.code === 0 && String(res.stdout || "").trim() === "1";
  } catch (e) {
    return false;
  }
}

// handleHealth — operator detail payload: which layer is unhappy, and whether
// the backend round-trip works. `healthy` mirrors /readyz.
function handleHealth() {
  const pgpool = checkPgpool();
  const backendAuth = pgpool ? checkBackendAuth() : false;
  return {
    healthy: pgpool && backendAuth,
    checks: { pgpool, backendAuth },
  };
}

function registerOpsRoutes() {
  api.get("/health/comprehensive", () => handleHealth());
}

module.exports = {
  registerOpsRoutes,
  handleHealth,
  checkPgpool,
  checkBackendAuth,
};
