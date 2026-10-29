// main.js — ezx bootstrap entrypoint for the WordPress (Apache + PHP) container.
//
// Replaces the bash entrypoint.sh tree with a small module set:
//
//   entrypoint.sh              -> main() below
//   validate_environment       -> validation.js
//   validate_dependencies      -> validation.js
//   setup/08-configure-apache  -> apache.js (provisionHttpdBase)
//   scripts/init/01..11        -> wpconfig.js + directories.js + phpini.js + apache.js
//   scripts/runtime/startup.sh -> directories.js (setup) + runtime.js (supervision)
//   runtime/healthcheck.sh     -> api.js (/health/comprehensive)
//   runtime/shutdown.sh        -> orchestrator ShutdownConfig + ForwardSignals
//
// Only slow/blocking work (compiling APR, httpd, PHP and its extensions) lives
// in the setup layer; every fast, idempotent config transform runs here so the
// image stays env-overridable.
//
// ezx stays PID 1 and supervises Apache (and the apache_exporter sidecar); the
// container authors no shell scripts. WordPress configuration is PHP source, so
// it is edited line-wise by wpconfig.js rather than with a key=value builder.
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
const { validateEnvironment } = require("./validation");
const { setupDirectories } = require("./directories");
const { provisionWpConfig } = require("./wpconfig");
const { provisionPhpIni } = require("./phpini");
const {
  provisionHttpdBase,
  provisionMpm,
  provisionStatus,
  provisionHtaccess,
  provisionExporterConfig,
} = require("./apache");
const { startApache, startSleep } = require("./runtime");
const { registerOpsRoutes } = require("./api");
const { provisionSecurityBaseline } = require("./security");
const { provisionPerformance } = require("./performance");

function main() {
  fs.umask(0o027);

  // Validate before any side effects (mirrors entrypoint.sh validate_environment
  // + validate_dependencies).
  if (!validateEnvironment()) {
    throw new Error("Environment validation failed");
  }

  // Directory, symlink and permission setup (init/03, init/11 and startup.sh).
  setupDirectories();

  // php.ini limits and OPcache (init/06).
  provisionPhpIni();

  // Optional hardening include (conf/extra/httpd-security.conf). Runs before
  // provisionHttpdBase so the file exists when its Include line is written.
  provisionSecurityBaseline();

  // Optional performance include (conf/extra/httpd-performance.conf): response
  // compression and browser caching. Also runs before provisionHttpdBase so its
  // Include line and module LoadModule edits are in place.
  provisionPerformance();

  // Apache httpd.conf: stock base config, then MPM, status, exporter
  // (setup/08 + init/07, 08, 09).
  provisionHttpdBase();
  provisionMpm();
  provisionStatus();
  provisionExporterConfig();

  // .htaccess rewrite + security rules (init/10).
  provisionHtaccess();

  // wp-config.php: DB settings, salts, env defines, HTTPS, table prefix
  // (init/01, 02, 04, 05). Runs last so the config file exists before Apache.
  provisionWpConfig();

  if (SLEEP_MODE) {
    log.info("Sleep mode");
    startSleep();
    return;
  }

  // Register operator routes before chain.run (which blocks the script).
  registerOpsRoutes();
  startApache();
  log.info("Entrypoint complete");
}

main();
