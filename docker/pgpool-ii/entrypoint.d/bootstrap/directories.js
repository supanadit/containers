// directories.js — port of the bash setup_directories() in entrypoint.sh.
// Creates the volume-normalized config/log/run directories and hands them to
// the pgpool user.
const { fs } = require("ezx");
const {
  PGPOOL_CONFIG_DIR,
  PGPOOL_LOG_DIR,
  PGPOOL_RUN_DIR,
  PGPOOL_USER,
  PGPOOL_GROUP,
} = require("./env");

function setupDirectories() {
  for (const dir of [PGPOOL_CONFIG_DIR, PGPOOL_LOG_DIR, PGPOOL_RUN_DIR]) {
    fs.ensureDir(dir, { mode: 0o755 });
    fs.chmod(dir, 0o755);
    fs.chown(dir, PGPOOL_USER + ":" + PGPOOL_GROUP);
  }
}

module.exports = { setupDirectories };
