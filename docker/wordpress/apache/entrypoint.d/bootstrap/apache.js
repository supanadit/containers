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
      MaxConnectionsPerChild: num(APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD, lowMemory ? 100 : 0),
    };
  }
  if (APACHE_MPM === "worker") {
    return {
      StartServers: num(APACHE_MPM_WORKER_START_SERVERS, lowMemory ? 1 : 3),
      MinSpareThreads: num(APACHE_MPM_WORKER_MIN_SPARE_THREADS, lowMemory ? 10 : 75),
      MaxSpareThreads: num(APACHE_MPM_WORKER_MAX_SPARE_THREADS, lowMemory ? 25 : 250),
      ThreadsPerChild: num(APACHE_MPM_WORKER_THREADS_PER_CHILD, lowMemory ? 10 : 25),
      MaxRequestWorkers: num(APACHE_MPM_WORKER_MAX_REQUEST_WORKERS, lowMemory ? 50 : 400),
      MaxConnectionsPerChild: num(APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD, lowMemory ? 100 : 0),
    };
  }
  // event (default)
  return {
    StartServers: num(APACHE_MPM_EVENT_START_SERVERS, lowMemory ? 1 : 3),
    MinSpareThreads: num(APACHE_MPM_EVENT_MIN_SPARE_THREADS, lowMemory ? 10 : 75),
    MaxSpareThreads: num(APACHE_MPM_EVENT_MAX_SPARE_THREADS, lowMemory ? 25 : 250),
    ThreadsPerChild: num(APACHE_MPM_EVENT_THREADS_PER_CHILD, lowMemory ? 10 : 25),
    MaxRequestWorkers: num(APACHE_MPM_EVENT_MAX_REQUEST_WORKERS, lowMemory ? 50 : 400),
    MaxConnectionsPerChild: num(APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD, lowMemory ? 100 : 0),
  };
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

  // The document-root <Directory> block: retarget the opener and set its own
  // AllowOverride/Require inside the block scope (so <Directory /> keeps its
  // restrictive defaults).
  conf.line('^\\s*<Directory\\s+"/usr/local/apache2/htdocs">', '<Directory "' + WORDPRESS_ROOT + '">');
  const dir = conf.wrap('<Directory "' + WORDPRESS_ROOT + '">', "</Directory>");
  dir.property("AllowOverride", "All");
  dir.property("Require", "all granted");

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

  // A custom MPM block is only applied when the matching MPM is selected and the
  // extra config is included (mirrors the bash guards).
  const customSelected =
    (APACHE_CUSTOM_MPM_PREFORK && APACHE_MPM === "prefork") ||
    (APACHE_CUSTOM_MPM_EVENT && APACHE_MPM === "event") ||
    (APACHE_CUSTOM_MPM_WORKER && APACHE_MPM === "worker");

  if (customSelected && includeMpm) {
    log.info("Configuring custom " + APACHE_MPM + " MPM settings");
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
// wp-config protections. Also the mod_info/server-info exclusions the exporter
// needs (init/09-apache-exporter.sh) so /server-status and /server-info bypass
// the WordPress front controller.
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
  if (APACHE_EXPORTER && APACHE_STATUS) {
    wp.add("RewriteCond", "%{REQUEST_URI} !^/wp-admin/");
    wp.add("RewriteCond", "%{REQUEST_URI} !^/server-status");
    wp.add("RewriteCond", "%{REQUEST_URI} !^/server-info");
  }
  wp.add("RewriteRule", ". /index.php [L]");

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
};
