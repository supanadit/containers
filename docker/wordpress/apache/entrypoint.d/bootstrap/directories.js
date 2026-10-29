// directories.js — port of the directory, symlink and permission management in
// startup.sh plus the stateless-file copy in init/11-permissions.sh.
//
// Responsibilities:
//   1. ensure the volume-normalized dirs exist and are owned by www-data
//   2. keep the backwards-compatible /content symlink -> /opt/containers/data
//   3. wire wp-content on the persistent volume (stateful) or only uploads
//      (stateless) into the document root
//   4. create the standard WordPress wp-content subdirectories
//   5. apply the (non-recursive, performance-conscious) permission pass
//   6. copy STATELESS_FILE_<name> files into wp-content
const { env, fs, log } = require("ezx");
const {
  DATA_DIR,
  CONFIG_DIR,
  LOG_DIR,
  RUN_DIR,
  CONTENT_DIR,
  WORDPRESS_USER,
  WORDPRESS_GROUP,
  WORDPRESS_ROOT,
  WORDPRESS_CONTENT_ROOT,
  DATA_WP_CONTENT,
  DATA_UPLOADS,
  CONTENT_STATELESS_DIR,
  IS_STATELESS,
  SKIP_PERMISSIONS,
} = require("./env");

const OWNER = WORDPRESS_USER + ":" + WORDPRESS_GROUP;

// chmodBestEffort — set a mode, but do not fail when the path is a read-only
// bind mount.
function chmodBestEffort(path, mode) {
  try {
    fs.chmod(path, mode);
  } catch (e) {
    log.warn("could not chmod " + path + " (read-only mount?): " + e.message);
  }
}

// chownBestEffort — change ownership but do not fail the bootstrap when it
// cannot (the bash entrypoint chowned with `|| true`). A hard failure here
// would abort the container before Apache ever starts.
function chownBestEffort(path) {
  try {
    fs.chownRecursive(path, OWNER);
  } catch (e) {
    log.warn("could not chown " + path + " (read-only mount?): " + e.message);
  }
}

// ensureOwned — mkdir -p + chmod + chown a single directory.
function ensureOwned(dir, mode) {
  fs.ensureDir(dir, { mode });
  chmodBestEffort(dir, mode);
  try {
    fs.chown(dir, OWNER);
  } catch (e) {
    log.warn("could not chown " + dir + ": " + e.message);
  }
}

// WP_SUBDIRS — the wp-content subdirectories WordPress expects to exist.
const WP_SUBDIRS = ["uploads", "uploads/fonts", "plugins", "themes", "upgrade"];

// ensureContentSymlink — /content is kept as an alias of the normalized data
// dir so existing volumes and the STATELESS_FILE_* convention keep working.
// fs.stat/exists follow symlinks, so a dangling symlink needs a remove+symlink
// rather than a create.
function ensureContentSymlink() {
  const target = resolveReal(DATA_DIR);
  const current = resolveReal(CONTENT_DIR);
  if (current === target) {
    return;
  }
  try {
    if (fs.exists(CONTENT_DIR)) {
      fs.removeAll(CONTENT_DIR);
    } else {
      // A dangling symlink (or nothing) — removing is a no-op when absent.
      try {
        fs.remove(CONTENT_DIR);
      } catch (e) {
        // ignore
      }
    }
    fs.symlink(DATA_DIR, CONTENT_DIR);
    log.info("Linked " + CONTENT_DIR + " -> " + DATA_DIR);
  } catch (e) {
    log.warn("could not create " + CONTENT_DIR + " symlink: " + e.message);
  }
}

// resolveReal — realpath, or null when the path does not resolve (including a
// dangling symlink, which fs.exists rejects).
function resolveReal(path) {
  try {
    return fs.realpath(path);
  } catch (e) {
    return null;
  }
}

// linkDir — make `path` a symlink pointing to `linkTarget`, replacing an
// existing directory, file or stale symlink.
function linkDir(path, linkTarget) {
  const target = resolveReal(linkTarget) || linkTarget;
  const current = resolveReal(path);
  if (current === target) {
    return;
  }
  try {
    if (fs.exists(path)) {
      fs.removeAll(path);
    } else {
      try {
        fs.remove(path);
      } catch (e) {
        // ignore: nothing to remove
      }
    }
  } catch (e) {
    log.warn("could not clear " + path + ": " + e.message);
  }
  fs.symlink(linkTarget, path);
  log.info("Linked " + path + " -> " + linkTarget);
}

// setupContentLayout — wire the persistent wp-content into the document root.
// Stateful mode keeps the whole wp-content tree; stateless mode persists only
// uploads, matching init/03-stateless.sh.
function setupContentLayout() {
  if (IS_STATELESS) {
    log.info("Configuring stateless mode - uploads only");
    fs.ensureDir(DATA_UPLOADS, { mode: 0o775 });
    chownBestEffort(DATA_UPLOADS);
    chmodBestEffort(DATA_UPLOADS, 0o775);
    linkDir(WORDPRESS_CONTENT_ROOT, DATA_UPLOADS);
    return;
  }

  log.info("Configuring stateful mode - full wp-content persistence");

  // Seed the persistent wp-content from the image's shipped wp-content the
  // first time the volume is used, then point the document root at it.
  const imageContent = WORDPRESS_ROOT + "/wp-content";
  if (!fs.exists(DATA_WP_CONTENT)) {
    fs.ensureDir(DATA_WP_CONTENT, { mode: 0o775 });
    if (fs.exists(imageContent)) {
      copyContents(imageContent, DATA_WP_CONTENT);
    }
  }
  chownBestEffort(DATA_WP_CONTENT);
  chmodBestEffort(DATA_WP_CONTENT, 0o775);

  linkDir(WORDPRESS_CONTENT_ROOT, DATA_WP_CONTENT);
}

// copyContents — copy the children of src into dest without a shell. Used only
// on first-run seeding; small and idempotent.
function copyContents(src, dest) {
  try {
    fs.copyTree(src, dest);
  } catch (e) {
    log.warn("could not seed " + dest + " from " + src + ": " + e.message);
  }
}

// ensureWpDirectories — create the wp-content subdirectories under both the
// persistent volume and (through the symlink) the document root.
function ensureWpDirectories() {
  const parent = IS_STATELESS ? DATA_UPLOADS : DATA_WP_CONTENT;
  for (const sub of WP_SUBDIRS) {
    const dir = parent + "/" + sub;
    fs.ensureDir(dir, { mode: 0o775 });
    chmodBestEffort(dir, 0o775);
    try {
      fs.chown(dir, OWNER);
    } catch (e) {
      log.warn("could not chown " + dir + ": " + e.message);
    }
  }
}

// applyPermissions — the performance-conscious permission pass from startup.sh:
// only the top-level directories are touched, never a recursive walk over a
// potentially huge wp-content.
function applyPermissions() {
  if (SKIP_PERMISSIONS) {
    log.info("Skipping permission changes (SKIP_PERMISSIONS=true)");
    return;
  }

  chmodBestEffort(WORDPRESS_ROOT, 0o755);
  try {
    fs.chown(WORDPRESS_ROOT, OWNER);
  } catch (e) {
    log.warn("could not chown " + WORDPRESS_ROOT + ": " + e.message);
  }

  const contentRoot = IS_STATELESS ? DATA_UPLOADS : DATA_WP_CONTENT;
  if (fs.exists(contentRoot)) {
    try {
      fs.chown(contentRoot, OWNER);
    } catch (e) {
      log.warn("could not chown " + contentRoot + ": " + e.message);
    }
    chmodBestEffort(contentRoot, 0o775);
  }
}

// copyStatelessFiles — handle STATELESS_FILE_<name>=<filename> vars: copy
// /content/stateless/<filename> into wp-content when the source exists
// (init/11-permissions.sh).
function copyStatelessFiles() {
  if (!IS_STATELESS) {
    return;
  }
  const re = /^STATELESS_FILE_(.+)$/;
  const all = env.all();
  for (const name of Object.keys(all)) {
    const m = re.exec(name);
    if (!m) {
      continue;
    }
    const filename = all[name];
    if (!filename) {
      continue;
    }
    const src = CONTENT_STATELESS_DIR + "/" + filename;
    const dest = WORDPRESS_CONTENT_ROOT + "/" + filename;
    if (!fs.exists(src)) {
      log.info("Stateless file not found, skipping: " + filename);
      continue;
    }
    try {
      fs.copy(src, dest);
      fs.chown(dest, OWNER);
      log.info("Copied stateless file: " + filename);
    } catch (e) {
      log.warn("could not copy stateless file " + filename + ": " + e.message);
    }
  }
}

function setupDirectories() {
  for (const dir of [DATA_DIR, CONFIG_DIR, LOG_DIR, RUN_DIR]) {
    ensureOwned(dir, 0o755);
  }

  ensureContentSymlink();
  setupContentLayout();
  ensureWpDirectories();
  applyPermissions();
  copyStatelessFiles();
}

module.exports = {
  setupDirectories,
  ensureContentSymlink,
  setupContentLayout,
  ensureWpDirectories,
  applyPermissions,
  copyStatelessFiles,
  chmodBestEffort,
  chownBestEffort,
  OWNER,
  WP_SUBDIRS,
};
