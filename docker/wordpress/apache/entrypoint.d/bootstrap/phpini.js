// phpini.js — PHP configuration (port of init/06-php-limits.sh).
//
// php.ini is an INI file, so this uses the editor's idempotent line operations
// rather than shelling out to awk: each setting is upserted (replace the
// matching line, or append when absent). OPcache is toggled by commenting or
// uncommenting the zend_extension line and setting opcache.enable.
const { editor, fs, log } = require("ezx");
const {
  PHP_INI,
  PHP_MEMORY_LIMIT,
  PHP_UPLOAD_MAX_FILESIZE,
  PHP_POST_MAX_SIZE,
  PHP_MAX_EXECUTION_TIME,
  PHP_MAX_INPUT_TIME,
  PHP_OPCACHE_ENABLE,
  PHP_OPCACHE_MEMORY,
  PHP_OPCACHE_MAX_ACCELERATED_FILES,
} = require("./env");

// upsertSetting — set "key = value" in php.ini (replace the existing direct/
// commented line, else append). The pattern tolerates leading whitespace and an
// optional `;` comment marker.
function upsertSetting(key, value) {
  const ed = editor.open(PHP_INI);
  const pattern = "^\\s*;?\\s*" + key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*=.*";
  ed.upsert(pattern, key + " = " + value);
}

// provisionPhpIni — apply the PHP limits and OPcache settings.
function provisionPhpIni() {
  if (!fs.exists(PHP_INI)) {
    log.warn("php.ini not found at " + PHP_INI + ", skipping PHP limits");
    return;
  }

  const limits = [
    ["memory_limit", PHP_MEMORY_LIMIT],
    ["upload_max_filesize", PHP_UPLOAD_MAX_FILESIZE],
    ["post_max_size", PHP_POST_MAX_SIZE],
    ["max_execution_time", PHP_MAX_EXECUTION_TIME],
    ["max_input_time", PHP_MAX_INPUT_TIME],
  ];
  for (const [key, value] of limits) {
    if (value) {
      log.info("Setting PHP " + key + ": " + value);
      upsertSetting(key, value);
    }
  }

  if (!PHP_OPCACHE_ENABLE) {
    log.info("Disabling PHP OPcache");
    const ed = editor.open(PHP_INI);
    // Comment the zend_extension line and force opcache.enable = 0.
    ed.remove("^\\s*zend_extension\\s*=.*opcache");
    ed.ensure("; zend_extension=opcache.so");
    ed.upsert("^\\s*;?\\s*opcache\\.enable\\s*=.*", "opcache.enable = 0");
    return;
  }

  log.info("Enabling PHP OPcache");
  const ed = editor.open(PHP_INI);
  ed.remove("^\\s*;\\s*zend_extension\\s*=.*opcache");
  ed.ensure("zend_extension=opcache.so");

  if (PHP_OPCACHE_MEMORY) {
    upsertSetting("opcache.memory_consumption", PHP_OPCACHE_MEMORY);
  }
  if (PHP_OPCACHE_MAX_ACCELERATED_FILES) {
    upsertSetting("opcache.max_accelerated_files", PHP_OPCACHE_MAX_ACCELERATED_FILES);
  }
}

module.exports = {
  provisionPhpIni,
  upsertSetting,
};
