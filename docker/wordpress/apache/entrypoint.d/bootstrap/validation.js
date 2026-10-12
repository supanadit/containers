// validation.js — port of validation.sh (validate_environment +
// validate_dependencies). Validates the container environment before any side
// effects: required database variables, required commands, and the presence of
// the WordPress sample config.
const { fs, log } = require("ezx");
const {
  WORDPRESS_DB_NAME,
  WORDPRESS_DB_USER,
  WORDPRESS_DB_PASSWORD,
  WORDPRESS_DB_HOST,
  WORDPRESS_SAMPLE_CONFIG,
  WORDPRESS_ROOT,
  APACHE_MPM,
} = require("./env");

// commandExists — true when the binary resolves via fs.which (the bash
// `command -v` guard).
function commandExists(cmd) {
  return !!fs.which(cmd);
}

// VALID_MPMS — the MPM choices init/07-apache-mpm.sh understands.
const VALID_MPMS = ["event", "prefork", "worker"];

function validateEnvironment() {
  let failed = false;
  const fail = (msg) => {
    log.error(msg);
    failed = true;
  };

  // Required database variables.
  const required = {
    WORDPRESS_DB_NAME,
    WORDPRESS_DB_USER,
    WORDPRESS_DB_PASSWORD,
    WORDPRESS_DB_HOST,
  };
  const missing = Object.keys(required).filter((k) => !required[k]);
  if (missing.length) {
    fail("Missing required environment variables: " + missing.join(" "));
  }

  // Required commands (the bash validate_dependencies list).
  const requiredCommands = ["awk", "sed", "curl", "chown", "chmod"];
  const missingCommands = requiredCommands.filter((c) => !commandExists(c));
  if (missingCommands.length) {
    fail("Missing required commands: " + missingCommands.join(" "));
  }

  // WordPress sample config must be present in the image.
  if (!fs.exists(WORDPRESS_SAMPLE_CONFIG)) {
    fail("WordPress sample config not found at " + WORDPRESS_SAMPLE_CONFIG);
  }

  // The document root must exist.
  if (!fs.exists(WORDPRESS_ROOT)) {
    fail("WordPress document root not found at " + WORDPRESS_ROOT);
  }

  // Apache MPM must be one of the supported choices.
  if (!VALID_MPMS.includes(APACHE_MPM)) {
    fail("APACHE_MPM must be one of " + VALID_MPMS.join(", ") + " (got '" + APACHE_MPM + "')");
  }

  return !failed;
}

module.exports = {
  validateEnvironment,
  commandExists,
  VALID_MPMS,
};
