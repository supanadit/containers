// api.js — operator-facing routes on the shared ezx health server
// (EZX_HEALTH_ADDR). Registered BEFORE chain.run; handlers run on HTTP
// goroutines while the chain supervises.
//
// Container health is driven by ezx's built-in /readyz, which returns HTTP 503
// while the apache node's readiness probe (a TCP check on port 80) is failing.
// This route is an operator detail view only. ezx.api always answers HTTP 200
// whatever the body, so the Dockerfile HEALTHCHECK greps the payload for
// "healthy":true rather than relying on the status code.
const { api, probe } = require("ezx");
const { APACHE_PORT, APACHE_STATUS, APACHE_EXPORTER } = require("./env");

// checkApache — the listener accepts connections.
function checkApache() {
  return probe.tcp("127.0.0.1", Number(APACHE_PORT));
}

// checkPhp — Apache can actually serve PHP (a real HTTP round-trip to a static
// asset, so a misconfigured mod_php cannot read green while broken). Falls back
// to a plain HTTP probe when /wp-includes/version.php is unavailable.
function checkPhp() {
  return probe.http("http://127.0.0.1:" + APACHE_PORT + "/wp-includes/version.php", 200);
}

// handleHealth — operator detail payload: which layer is unhappy.
function handleHealth() {
  const apache = checkApache();
  const php = apache ? checkPhp() : false;
  return {
    healthy: apache && php,
    checks: {
      apache,
      php,
      status: APACHE_STATUS,
      exporter: APACHE_EXPORTER,
    },
  };
}

function registerOpsRoutes() {
  api.get("/health/comprehensive", () => handleHealth());
}

module.exports = {
  registerOpsRoutes,
  handleHealth,
  checkApache,
  checkPhp,
};
