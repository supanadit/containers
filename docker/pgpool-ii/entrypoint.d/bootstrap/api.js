// api.js — operator-facing routes on the shared ezx health server
// (EZX_HEALTH_ADDR). Registered BEFORE chain.run; handlers run on HTTP
// goroutines while the chain supervises.
const { api, probe } = require("ezx");
const { PGPOOL_PORT } = require("./env");

// checkPgpool — the listener accepts connections.
function checkPgpool() {
  return probe.tcp("127.0.0.1", Number(PGPOOL_PORT));
}

// handleHealth — composite health payload (port of runtime/healthcheck.sh).
function handleHealth() {
  const checks = { pgpool: checkPgpool() };
  return { healthy: checks.pgpool, checks };
}

function registerOpsRoutes() {
  api.get("/health/comprehensive", () => handleHealth());
}

module.exports = {
  registerOpsRoutes,
  handleHealth,
  checkPgpool,
};
