// validation.js — port of the bash validate_environment() in entrypoint.sh.
// Validates the container environment before any side effects: required
// backends, Patroni prerequisites, watchdog requirements, and SSL key/cert
// presence.
const { fs, log } = require("ezx");
const {
  PGPOOL_BACKENDS,
  PGPOOL_PATRONI_ENDPOINTS,
  PGPOOL_ENABLE_WATCHDOG,
  PGPOOL_WD_HOSTNAME,
  PGPOOL_DELEGATE_IP,
  PGPOOL_SSL,
  PGPOOL_SSL_KEY,
  PGPOOL_SSL_CERT,
} = require("./env");

// commandExists — true when the binary resolves via fs.which (the bash
// `command -v` guard).
function commandExists(cmd) {
  return !!fs.which(cmd);
}

function validateEnvironment() {
  let failed = false;
  const fail = (msg) => {
    log.error(msg);
    failed = true;
  };

  // PGPOOL_BACKENDS is required (at least one host:port).
  if (!PGPOOL_BACKENDS) {
    log.error("PGPOOL_BACKENDS environment variable is required");
    log.error("Example: PGPOOL_BACKENDS='172.10.10.5:5432,172.10.10.6:5432,172.10.10.7:5432'");
    return false;
  }

  // Patroni integration: informational only. The native pgpool hooks are
  // user-supplied via PGPOOL_FOLLOW_MASTER_SCRIPT; the container no longer
  // generates a helper script, so curl/jq are no longer required.
  if (PGPOOL_PATRONI_ENDPOINTS) {
    log.info("Patroni integration endpoints configured");
  }

  // Watchdog requires a hostname and a delegate IP.
  if (PGPOOL_ENABLE_WATCHDOG) {
    log.info("Watchdog enabled");
    if (!PGPOOL_WD_HOSTNAME) {
      fail("PGPOOL_WD_HOSTNAME is required when watchdog is enabled");
    }
    if (!PGPOOL_DELEGATE_IP) {
      fail("PGPOOL_DELEGATE_IP is required when watchdog is enabled");
    }
  }

  // SSL: warn (not fail) when enabled without key/cert, matching bash.
  if (PGPOOL_SSL) {
    if (!PGPOOL_SSL_KEY || !PGPOOL_SSL_CERT) {
      log.warn("SSL enabled but SSL_KEY or SSL_CERT not provided");
    }
  }

  // pgpool-II must be installed.
  if (!commandExists("pgpool")) {
    fail("pgpool command not found. Please ensure pgpool-II is properly installed.");
  }

  return !failed;
}

module.exports = {
  validateEnvironment,
  commandExists,
};
