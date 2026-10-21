// apache.js — Apache httpd runtime configuration (port of setup/08-configure-apache.sh
// for the stock base edits, plus init/07-apache-mpm.sh, 08-apache-status.sh,
// 10-htaccess.sh and the config half of 09-apache-exporter.sh).
//
// All edits use the fluent editor verbs (property/line/add/wrap/section/raw),
// which are idempotent and position-preserving, so a restart converges to the
// same state with no hand-assembled config text. The stock base config runs at
// runtime (not build time) so it stays env-overridable and follows the
// "only slow/blocking work belongs in the setup layer" rule.
const { editor, fs, log } = require("ezx");
const { apacheSecurityInclude, provisionHtaccessSecurity } = require("./security");
const {
  APACHE_CONF,
  APACHE_STATUS_CONF,
  APACHE_MPM_CONF,
  APACHE_MPM,
  APACHE_LOW_MEMORY_MODE,
  APACHE_INCLUDE_CONFIG_MPM,
  APACHE_CUSTOM_MPM_PREFORK,
  APACHE_CUSTOM_MPM_EVENT,
  APACHE_CUSTOM_MPM_WORKER,
  APACHE_MPM_PREFORK_START_SERVERS,
  APACHE_MPM_PREFORK_MIN_SPARE_SERVERS,
  APACHE_MPM_PREFORK_MAX_SPARE_SERVERS,
  APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS,
  APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD,
  APACHE_MPM_EVENT_START_SERVERS,
  APACHE_MPM_EVENT_MIN_SPARE_THREADS,
  APACHE_MPM_EVENT_MAX_SPARE_THREADS,
  APACHE_MPM_EVENT_THREADS_PER_CHILD,
  APACHE_MPM_EVENT_MAX_REQUEST_WORKERS,
  APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD,
  APACHE_MPM_WORKER_START_SERVERS,
  APACHE_MPM_WORKER_MIN_SPARE_THREADS,
  APACHE_MPM_WORKER_MAX_SPARE_THREADS,
  APACHE_MPM_WORKER_THREADS_PER_CHILD,
  APACHE_MPM_WORKER_MAX_REQUEST_WORKERS,
  APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD,
  APACHE_STATUS,
  APACHE_STATUS_PUBLIC,
  APACHE_EXPORTER,
  IS_PROTECT_XMLRPC,
  IS_PROTECT_WPCONFIG,
  WORDPRESS_ROOT,
  WORDPRESS_USER,
  WORDPRESS_GROUP,
} = require("./env");

// MODULES — the stock modules WordPress needs uncommented.
const MODULES = ["rewrite", "headers", "env", "mime", "dir"];

// PHP_MIME_TYPES — the PHP handlers mod_php needs.
const PHP_MIME_TYPES = [".php", ".html", ".htm", ".phtml"];

// num — coerce an env string to a number, falling back to a default.
function num(value, def) {
  const n = parseInt(value, 10);
  return Number.isInteger(n) ? n : def;
}

// mpmSettings — resolve the effective MPM tuning values, honoring the
// low-memory defaults (init/07-apache-mpm.sh).
function mpmSettings() {
  const lowMemory = APACHE_LOW_MEMORY_MODE;
  if (APACHE_MPM === "prefork") {
    return {
      StartServers: num(APACHE_MPM_PREFORK_START_SERVERS, lowMemory ? 2 : 5),
      MinSpareServers: num(APACHE_MPM_PREFORK_MIN_SPARE_SERVERS, lowMemory ? 1 : 5),
      MaxSpareServers: num(APACHE_MPM_PREFORK_MAX_SPARE_SERVERS, lowMemory ? 3 : 10),
      MaxRequestWorkers: num(APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS, lowMemory ? 10 : 250),
      // A finite value is deliberate even outside low-memory mode: an unbounded
      // worker (0) never releases leaked memory and is the classic cause of a
      // long-uptime container slowly sliding into swap.
      MaxConnectionsPerChild: num(APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD, lowMemory ? 100 : 10000),
    };
  }
  if (APACHE_MPM === "worker") {
    return {
      StartServers: num(APACHE_MPM_WORKER_START_SERVERS, lowMemory ? 1 : 3),
      MinSpareThreads: num(APACHE_MPM_WORKER_MIN_SPARE_THREADS, lowMemory ? 10 : 75),
      MaxSpareThreads: num(APACHE_MPM_WORKER_MAX_SPARE_THREADS, lowMemory ? 25 : 250),
      ThreadsPerChild: num(APACHE_MPM_WORKER_THREADS_PER_CHILD, lowMemory ? 10 : 25),
      MaxRequestWorkers: num(APACHE_MPM_WORKER_MAX_REQUEST_WORKERS, lowMemory ? 50 : 400),
      // Finite by default so workers recycle and release memory over time.
      MaxConnectionsPerChild: num(APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD, lowMemory ? 100 : 10000),
    };
  }
  // event (default)
  return {
    StartServers: num(APACHE_MPM_EVENT_START_SERVERS, lowMemory ? 1 : 3),
    MinSpareThreads: num(APACHE_MPM_EVENT_MIN_SPARE_THREADS, lowMemory ? 10 : 75),
    MaxSpareThreads: num(APACHE_MPM_EVENT_MAX_SPARE_THREADS, lowMemory ? 25 : 250),
    ThreadsPerChild: num(APACHE_MPM_EVENT_THREADS_PER_CHILD, lowMemory ? 10 : 25),
    MaxRequestWorkers: num(APACHE_MPM_EVENT_MAX_REQUEST_WORKERS, lowMemory ? 50 : 400),
    // Finite by default so workers recycle and release memory over time.
    MaxConnectionsPerChild: num(APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD, lowMemory ? 100 : 10000),
  };
}

// escapeRegExp — escape a literal string for use inside a RegExp source.
function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// provisionHttpdBase — the stock httpd.conf transforms that used to live in
// setup/08-configure-apache.sh. They point httpd at the WordPress document root,
// drop worker privileges to www-data, load mod_php, set index.php as the
// directory index and enable the modules WordPress needs.
function provisionHttpdBase() {
  const conf = editor.open(APACHE_CONF);

  // scalars (position-preserving)
  conf.property("DocumentRoot", '"' + WORDPRESS_ROOT + '"');
  conf.property("User", WORDPRESS_USER);
  conf.property("Group", WORDPRESS_GROUP);
  conf.property("DirectoryIndex", "index.php index.html");

  // The document-root <Directory> block. `conf.property`/`conf.wrap` append at
  // EOF when their pattern does not match, and there is at most one matching
  // `<Directory ...>` opener per run. A second run (docker restart, crash-loop,
  // host reboot) would otherwise append ANOTHER opener with no closer, leaving
  // httpd.conf unparseable. So this block is written once: the opener is only
  // retargeted while the retargeted form is not already present, and the
  // in-block directives are only set when the opener was actually retargeted.
  const alreadyRetargeted = new RegExp(
    '^\\s*<Directory\\s+"' + escapeRegExp(WORDPRESS_ROOT) + '">',
    "m",
  ).test(conf.read());
  if (!alreadyRetargeted) {
    conf.line('^\\s*<Directory\\s+"/usr/local/apache2/htdocs">', '<Directory "' + WORDPRESS_ROOT + '">');
    const dir = conf.wrap('<Directory "' + WORDPRESS_ROOT + '">', "</Directory>");
    dir.property("AllowOverride", "All");
    dir.property("Require", "all granted");
  }

  // mod_php + MIME handlers
  conf.add("LoadModule", "php_module modules/libphp.so");
  for (const type of PHP_MIME_TYPES) {
    conf.add("AddType", "application/x-httpd-php " + type);
  }

  // Uncomment the shipped module lines.
  for (const mod of MODULES) {
    conf.line(
      "^\\s*#?\\s*LoadModule\\s+" + mod + "_module",
      "LoadModule " + mod + "_module modules/mod_" + mod + ".so",
    );
  }

  // Pull in the container-owned hardening include last, so its server-scope
  // directives apply after the stock defaults.
  apacheSecurityInclude();
}

// setModule — comment or uncomment the LoadModule line for an MPM module, in
// place (the MPM line must keep its position among the other LoadModules).
function setModule(conf, mod, enabled) {
  conf.line(
    "^\\s*#?\\s*LoadModule\\s+" + mod + "_module",
    (enabled ? "" : "#") + "LoadModule " + mod + "_module modules/mod_" + mod + ".so",
  );
}

// provisionMpm — the init/07-apache-mpm.sh flow.
function provisionMpm() {
  const conf = editor.open(APACHE_CONF);

  setModule(conf, "mpm_event", APACHE_MPM === "event");
  setModule(conf, "mpm_worker", APACHE_MPM === "worker");
  setModule(conf, "mpm_prefork", APACHE_MPM === "prefork");

  // Low memory mode implies the extra MPM config include.
  const includeMpm = APACHE_INCLUDE_CONFIG_MPM || APACHE_LOW_MEMORY_MODE;
  if (includeMpm) {
    conf.line("^\\s*#?\\s*Include\\s+conf/extra/httpd-mpm\\.conf", "Include conf/extra/httpd-mpm.conf");
  }

  // The MPM block is written when the extra config is included and either a
  // per-MPM custom flag is set, or APACHE_LOW_MEMORY_MODE is on. Low-memory mode
  // alone is therefore sufficient (as the docs promise): mpmSettings() supplies
  // the low-memory defaults, and any explicit APACHE_MPM_* value still wins.
  // Without the APACHE_LOW_MEMORY_MODE clause the documented "just set
  // APACHE_LOW_MEMORY_MODE" workflow silently wrote no settings at all.
  const customSelected =
    (APACHE_CUSTOM_MPM_PREFORK && APACHE_MPM === "prefork") ||
    (APACHE_CUSTOM_MPM_EVENT && APACHE_MPM === "event") ||
    (APACHE_CUSTOM_MPM_WORKER && APACHE_MPM === "worker");

  if (includeMpm && (customSelected || APACHE_LOW_MEMORY_MODE)) {
    log.info(
      "Configuring " + (customSelected ? "custom " : "low-memory ") + APACHE_MPM + " MPM settings",
    );
    const block = editor.open(APACHE_MPM_CONF).wrap(
      "<IfModule mpm_" + APACHE_MPM + "_module>",
      "</IfModule>",
    );
    block.reset();
    for (const [key, value] of Object.entries(mpmSettings())) {
      block.property(key, String(value));
    }
  }
}

// provisionStatus — init/08-apache-status.sh: enable mod_status, write
// httpd-status.conf, optionally expose it publicly, and include it.
function provisionStatus() {
  if (!APACHE_STATUS) {
    return;
  }
  log.info("Enabling Apache server status");

  const conf = editor.open(APACHE_CONF);
  conf.add("LoadModule", "status_module modules/mod_status.so");

  // httpd-status.conf is fully owned by the container: reset, then build it.
  const status = editor.open(APACHE_STATUS_CONF);
  status.reset();
  status.property("ExtendedStatus", "On");
  const location = status.wrap("<Location /server-status>", "</Location>");
  location.property("SetHandler", "server-status");
  location.property("Require", APACHE_STATUS_PUBLIC ? "all granted" : "local");
  fs.chmod(APACHE_STATUS_CONF, 0o644);

  conf.line("^\\s*#?\\s*Include\\s+conf/extra/httpd-status\\.conf", "Include conf/extra/httpd-status.conf");
}

// provisionHtaccess — init/10-htaccess.sh: WordPress rewrite rules, xmlrpc and
// wp-config protections. /server-status bypasses the WordPress front controller
// whenever APACHE_STATUS is on; /server-info only when the exporter (which loads
// mod_info) is enabled.
function provisionHtaccess() {
  const htaccess = WORDPRESS_ROOT + "/.htaccess";
  const ed = editor.open(htaccess);

  // The rewrite block is a comment-delimited managed section: ezx writes the
  // markers and owns only the region between them. reset() makes the region
  // fully owned so repeatable directives (RewriteCond/RewriteRule) do not
  // accumulate across restarts.
  const wp = ed.sectionNamed("wordpress", "# BEGIN WordPress", "# END WordPress");
  wp.reset();
  wp.property("RewriteEngine", "On");
  wp.property("RewriteBase", "/");
  wp.add("RewriteRule", "^index\\.php$ - [L]");
  wp.add("RewriteCond", "%{REQUEST_FILENAME} !-f");
  wp.add("RewriteCond", "%{REQUEST_FILENAME} !-d");
  // /server-status bypasses the WordPress front controller whenever Apache
  // status is enabled. This must NOT depend on APACHE_EXPORTER: the exporter is
  // only the optional metrics sidecar, and gating this on it made
  // /server-status 404 (rewritten to index.php) for anyone who enabled
  // APACHE_STATUS on its own.
  if (APACHE_STATUS) {
    wp.add("RewriteCond", "%{REQUEST_URI} !^/server-status");
  }
  // mod_info (and therefore /server-info) is only loaded alongside the
  // exporter, so its exclusion stays tied to it.
  if (APACHE_EXPORTER && APACHE_STATUS) {
    wp.add("RewriteCond", "%{REQUEST_URI} !^/wp-admin/");
    wp.add("RewriteCond", "%{REQUEST_URI} !^/server-info");
  }
  wp.add("RewriteRule", ". /index.php [L]");

  // Optional hardening rules (sensitive files, wp-login allowlist). Owned by
  // security.js and written into their own managed sections.
  provisionHtaccessSecurity(ed);

  provisionSecurity(ed);

  try {
    fs.chown(htaccess, "www-data:www-data");
    fs.chmod(htaccess, 0o775);
  } catch (e) {
    log.warn("could not set .htaccess permissions: " + e.message);
  }
}

// provisionSecurity — the optional xmlrpc.php and wp-config.php protections
// (init/10-htaccess.sh).
function provisionSecurity(ed) {
  if (IS_PROTECT_XMLRPC) {
    const b = ed.sectionNamed("xmlrpc", "<Files xmlrpc.php>", "</Files>");
    b.reset();
    b.property("order", "deny,allow");
    b.property("deny", "from all");
    log.info("Protecting xmlrpc.php");
  }
  if (IS_PROTECT_WPCONFIG) {
    const b = ed.sectionNamed("wpconfig", "<Files wp-config.php>", "</Files>");
    b.reset();
    b.property("Require", "all denied");
    log.info("Protecting wp-config.php");
  }
}

// provisionExporterConfig — the httpd.conf change from init/09-apache-exporter.sh:
// load mod_info so /server-info is available. The exporter process itself is
// supervised at runtime (runtime.js); the scrape URI points at /server-status.
function provisionExporterConfig() {
  if (!(APACHE_EXPORTER && APACHE_STATUS)) {
    return;
  }
  editor.open(APACHE_CONF).add("LoadModule", "info_module modules/mod_info.so");
}

module.exports = {
  provisionHttpdBase,
  provisionMpm,
  provisionStatus,
  provisionHtaccess,
  provisionExporterConfig,
  provisionSecurity,
  mpmSettings,
  setModule,
  escapeRegExp,
};
