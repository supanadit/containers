// wpconfig.js — WordPress wp-config.php management (port of utils/wordpress.sh
// and init/01-wp-config.sh, 02-wordpress-vars.sh, 04-https.sh, 05-table-prefix.sh).
//
// wp-config.php is PHP source, managed through the fluent editor verbs:
//   - property/line/define   — set scalars and PHP constants in place
//   - fragment               — include a shipped .php file under a named fence
//                              (so PHP is never written as a JS string)
//   - reset                  — clear a zone the container owns
// The container must:
//   - seed it from wp-config-sample.php on first run and fill in the DB settings
//   - replace the salt placeholders with fresh keys
//   - include the loopback-request fix (always) and the HTTPS shim (IS_HTTPS)
//   - persist it on the data volume (stateful) and symlink it back
//   - overlay every WORDPRESS_<NAME> env var as a define()
//   - set the table prefix
const { env, editor, fs, log, net, crypto } = require("ezx");
const {
  WORDPRESS_CONFIG_FILE,
  WORDPRESS_SAMPLE_CONFIG,
  DATA_DIR,
  IS_STATELESS,
  IS_HTTPS,
  CUSTOM_TABLE_PREFIX,
  WORDPRESS_DB_NAME,
  WORDPRESS_DB_USER,
  WORDPRESS_DB_PASSWORD,
  WORDPRESS_DB_HOST,
  PHP_DIR,
} = require("./env");

// PERSISTED_CONFIG — wp-config.php lives on the data volume in stateful mode.
const PERSISTED_CONFIG = DATA_DIR + "/wp-config.php";

// FILES — the shipped PHP fragments, included into wp-config.php by path.
const FRAGMENT_HTTPS = PHP_DIR + "/https.php";
const FRAGMENT_LOOPBACK = PHP_DIR + "/loopback.php";

// SALTS — the eight keys WordPress ships as placeholders.
const SALTS = [
  "AUTH_KEY",
  "SECURE_AUTH_KEY",
  "LOGGED_IN_KEY",
  "NONCE_KEY",
  "AUTH_SALT",
  "SECURE_AUTH_SALT",
  "LOGGED_IN_SALT",
  "NONCE_SALT",
];

// conf — open wp-config.php with the PHP comment style ("//") so section/fragment
// fences render as PHP comments.
function conf() {
  return editor.open(WORDPRESS_CONFIG_FILE, { comment: "//" });
}

// generateSalts — fresh salts from the WordPress API, falling back to locally
// generated random values (utils/wordpress.sh generate_wordpress_salts).
function generateSalts() {
  try {
    const res = net.http({ url: "https://api.wordpress.org/secret-key/1.1/salt/", method: "GET", timeout: 10e9 });
    const body = (res && res.body) || "";
    if (body && body.indexOf("define(") !== -1) {
      return body.trim().split("\n");
    }
  } catch (e) {
    log.warn("WordPress salt API failed (" + e.message + "), generating salts locally");
  }
  return SALTS.map((key) => "define('" + key + "', '" + crypto.randomHex(32) + "');");
}

// ensureConfig — resolve the effective wp-config.php location and seed it if
// needed. Stateful mode persists it on the data volume and symlinks it into the
// document root.
function ensureConfig() {
  if (fs.exists(PERSISTED_CONFIG)) {
    log.info("Using existing wp-config.php from " + PERSISTED_CONFIG);
    // Replace the document-root copy with a symlink to the persisted file. The
    // doc-root path may itself already be a symlink (dangling when the volume
    // moved), so remove best-effort before linking.
    try {
      fs.remove(WORDPRESS_CONFIG_FILE);
    } catch (e) {
      // ignore: nothing to remove
    }
    fs.symlink(PERSISTED_CONFIG, WORDPRESS_CONFIG_FILE);
    return;
  }

  if (!fs.exists(WORDPRESS_CONFIG_FILE)) {
    log.info("Creating wp-config.php from sample");
    seedConfig();
  }

  if (!IS_STATELESS && !fs.exists(PERSISTED_CONFIG)) {
    try {
      fs.copy(WORDPRESS_CONFIG_FILE, PERSISTED_CONFIG);
      fs.chown(PERSISTED_CONFIG, "www-data:www-data");
      log.info("Persisted wp-config.php to " + PERSISTED_CONFIG);
    } catch (e) {
      log.warn("could not persist wp-config.php: " + e.message);
    }
  }
}

// seedConfig — create wp-config.php from the sample: fill the database settings
// and replace the salt placeholders with fresh keys.
function seedConfig() {
  const wp = editor.open(WORDPRESS_CONFIG_FILE, { comment: "//" });
  wp.replace(editor.open(WORDPRESS_SAMPLE_CONFIG).read());

  wp.define("DB_NAME", WORDPRESS_DB_NAME);
  wp.define("DB_USER", WORDPRESS_DB_USER);
  wp.define("DB_PASSWORD", WORDPRESS_DB_PASSWORD);
  wp.define("DB_HOST", WORDPRESS_DB_HOST);

  // The sample ships the eight salts as "put your unique phrase here"
  // placeholders; replace each with a generated value.
  if (wp.read().indexOf("put your unique phrase here") !== -1) {
    log.info("Generating and updating WordPress salts");
    for (const line of generateSalts()) {
      const m = /define\(\s*['"]([A-Z_]+)['"]\s*,\s*['"](.*)['"]\s*\);/.exec(line);
      if (!m) continue;
      // Set the exact salt line, replacing the placeholder in place.
      wp.line("^\\s*define\\(\\s*['\"]" + m[1] + "['\"]", "define('" + m[1] + "', '" + m[2] + "');");
    }
  }
}

// applyEnvDefines — overlay every WORDPRESS_<NAME> env var as a define()
// (init/02-wordpress-vars.sh).
function applyEnvDefines() {
  // Container-internal WORDPRESS_* variables that must never leak into
  // wp-config.php. Everything else matching WORDPRESS_<NAME> is a user-supplied
  // WordPress constant (e.g. WORDPRESS_WP_DEBUG, WORDPRESS_WP_MEMORY_LIMIT).
  const skip = new Set([
    "WORDPRESS_DB_NAME",
    "WORDPRESS_DB_USER",
    "WORDPRESS_DB_PASSWORD",
    "WORDPRESS_DB_HOST",
    "WORDPRESS_DB_CHARSET",
    "WORDPRESS_DB_COLLATE",
    "WORDPRESS_ROOT",
    "WORDPRESS_USER",
    "WORDPRESS_GROUP",
    "WORDPRESS_DATA_DIR",
    "WORDPRESS_CONFIG_DIR",
    "WORDPRESS_LOG_DIR",
    "WORDPRESS_RUN_DIR",
    "WORDPRESS_CONTENT_DIR",
    "WORDPRESS_CONTENT_ROOT",
    "WORDPRESS_CONFIG_FILE",
    "WORDPRESS_PHP_DIR",
  ]);

  const wp = conf();
  const all = env.all();
  const re = /^WORDPRESS_([A-Z0-9_]+)$/;
  const names = Object.keys(all)
    .filter((n) => re.test(n) && !skip.has(n))
    .sort();
  for (const name of names) {
    wp.define(name.replace(/^WORDPRESS_/, ""), all[name]);
  }
}

// applyFragments — include the shipped PHP fragments. The loopback fix is always
// present; the HTTPS shim is included or removed based on IS_HTTPS
// (init/04-https.sh).
function applyFragments() {
  const wp = conf();
  wp.fragment("loopback", FRAGMENT_LOOPBACK);
  wp.fragment("https", IS_HTTPS ? FRAGMENT_HTTPS : "", { after: "^<\\?php" });
}

// applyTablePrefix — set $table_prefix (init/05-table-prefix.sh).
function applyTablePrefix() {
  if (!CUSTOM_TABLE_PREFIX) {
    return;
  }
  conf().line("^\\s*\\$table_prefix\\s*=", "$table_prefix = '" + CUSTOM_TABLE_PREFIX + "';");
}

// provisionWpConfig — the ordered wp-config pipeline.
function provisionWpConfig() {
  ensureConfig();
  applyEnvDefines();
  applyFragments();
  applyTablePrefix();
  // Final ownership pass: provisioning runs as root, Apache writes as www-data.
  try {
    fs.chown(WORDPRESS_CONFIG_FILE, "www-data:www-data");
    fs.chmod(WORDPRESS_CONFIG_FILE, 0o644);
  } catch (e) {
    log.warn("could not fix wp-config.php ownership: " + e.message);
  }
}

module.exports = {
  provisionWpConfig,
  ensureConfig,
  seedConfig,
  applyEnvDefines,
  applyFragments,
  applyTablePrefix,
  generateSalts,
  SALTS,
};
