// backup.js — MariaDB backups: pgBackRest-style chains, 100% JS on ezx's
// native APIs.
//
// Model (mirrors the pgBackRest full/incremental chain idea):
//   * a FULL artifact starts a chain:       full_YYYYMMDD_HHMMSS/
//   * INCREMENTALs extend the newest chain: incr_YYYYMMDD_HHMMSS/
//     (each is taken with --incremental-basedir pointing at the newest open
//      base: the full, or the previous incremental)
//   * every artifact is prepared as it is created, with --apply-log-only, so
//     the base accumulates the chain and a restore needs only one final
//     `mariabackup --prepare` (without --apply-log-only)
//   * taking a new FULL closes the previous chain: its base gets that final
//     prepare and becomes a fully consistent, copy-back-able image
//   * retention expires WHOLE chains (never a middle incremental) and always
//     keeps the newest one
//
// Chain state is recorded with marker FILES (ezx's fs has no read/text API):
//   <artifact>/.prepared   → apply-log-only prepare succeeded (open base)
//   <artifact>/.consistent → final prepare done (chain closed)
//
// Only the physical hot-backup tool runs here (mariabackup). Logical dumps
// (mariadb-dump/mysqldump) are deliberately not part of the managed path: the
// binaries stay in the image for users to run or extend themselves, exactly
// like pg_dump/pg_restore in the postgresql image. There is no dump fallback.
const { fs, process, log } = require("ezx");
const {
	MARIADB_BACKUP_DIR,
	MARIADB_BACKUP_METHOD,
	MARIADB_BACKUP_RETENTION_DAYS,
	MARIADB_BACKUP_S3_BUCKET,
	MARIADB_BACKUP_S3_REGION,
	MARIADB_BACKUP_S3_ENDPOINT,
	MARIADB_BACKUP_SFTP_HOST,
	MARIADB_BACKUP_SFTP_PORT,
	MARIADB_BACKUP_SFTP_USER,
	MARIADB_BACKUP_SFTP_KEY,
	MARIADB_BACKUP_SFTP_DEST,
	MARIADB_DATA_DIR,
	MARIADB_RUN_DIR,
	MARIADB_SOCKET,
	MARIADB_ROOT_PASSWORD,
} = require("./env");

const MYSQL_USER = "mysql";
const MYSQL_GROUP = "mysql";

// LOCK lives in the run dir (container-local, not a volume) so a stale lock
// cannot outlive the container and block every future backup.
const BACKUP_LOCK = MARIADB_RUN_DIR + "/backup.lock";
const MARKER_PREPARED = ".prepared";
const MARKER_CONSISTENT = ".consistent";

// pad — zero-pad a number to two digits for timestamp components.
function pad(n) {
	return String(n).padStart(2, "0");
}

// timestamp — YYYYMMDD_HHMMSS from a Date (matches the old shell `date +%Y%m%d_%H%M%S`).
function timestamp(now) {
	return (
		now.getFullYear() +
		pad(now.getMonth() + 1) +
		pad(now.getDate()) +
		"_" +
		pad(now.getHours()) +
		pad(now.getMinutes()) +
		pad(now.getSeconds())
	);
}

// parseTs — Date from a YYYYMMDD_HHMMSS stamp, null when unparseable.
function parseTs(ts) {
	const t = Number(ts.replace("_", ""));
	if (!isFinite(t)) return null;
	return new Date(
		Number(ts.slice(0, 4)),
		Number(ts.slice(4, 6)) - 1,
		Number(ts.slice(6, 8)),
		Number(ts.slice(9, 11)),
		Number(ts.slice(11, 13)),
		Number(ts.slice(13, 15)),
	);
}

// ---------------------------------------------------------------------------
// Artifact bookkeeping
// ---------------------------------------------------------------------------

// parseArtifact — {type, ts} for full_/incr_ artifacts, null otherwise.
// Legacy names from the pre-chain layout (backup_<ts>, full_backup_<ts>.sql)
// are not artifacts but are still reaped by retention.
function parseArtifact(name) {
	const m = /^(full|incr)_(\d{8}_\d{6})$/.exec(name);
	if (!m) return null;
	return { name: name, type: m[1], ts: m[2] };
}

// listArtifacts — every artifact in the backup dir, oldest first.
function listArtifacts() {
	const out = [];
	for (const entry of fs.readDir(MARIADB_BACKUP_DIR)) {
		const a = parseArtifact(entry);
		if (a) out.push(a);
	}
	return out.sort((x, y) => (x.ts < y.ts ? -1 : x.ts > y.ts ? 1 : 0));
}

function markerPath(a, marker) {
	return MARIADB_BACKUP_DIR + "/" + a.name + "/" + marker;
}

// isOpenBase — prepared with --apply-log-only and not yet closed, i.e. a valid
// --incremental-basedir for the next incremental.
function isOpenBase(a) {
	return fs.exists(markerPath(a, MARKER_PREPARED)) && !fs.exists(markerPath(a, MARKER_CONSISTENT));
}

// isClosed — chain closed with the final prepare (restore-ready as-is).
function isClosed(a) {
	return fs.exists(markerPath(a, MARKER_CONSISTENT));
}

// latestBase — newest open base, the correct --incremental-basedir.
function latestBase() {
	const all = listArtifacts();
	for (let i = all.length - 1; i >= 0; i--) {
		if (isOpenBase(all[i])) return all[i];
	}
	return null;
}

// chains — group artifacts into chains: a full starts one, the following
// incrementals belong to it. Returns [{base, members: [...]}, ...] oldest first.
function chains() {
	const out = [];
	for (const a of listArtifacts()) {
		if (a.type === "full") {
			out.push({ base: a, members: [a] });
		} else if (out.length > 0 && out[out.length - 1].base.type === "full") {
			out[out.length - 1].members.push(a);
		}
		// An incr with no preceding full is an orphan: unusable, so it is left
		// for retention to reap instead of being treated as a base.
	}
	return out;
}

// ---------------------------------------------------------------------------
// Tool invocations
// ---------------------------------------------------------------------------

// backupArgs — mariabackup/xtrabackup --backup argument list (args array, no
// shell). --datadir is required: the container's my.cnf lives at a
// non-standard path (/opt/containers/config/my.cnf) so the tool cannot infer
// the data directory. For incrementals, baseDir is the previous chain member.
function backupArgs(targetDir, baseDir) {
	const args = [
		"--backup",
		"--target-dir=" + targetDir,
		"--datadir=" + MARIADB_DATA_DIR,
		"--socket=" + MARIADB_SOCKET,
		"--skip-ssl",
		"--user=root",
		"--password=" + MARIADB_ROOT_PASSWORD,
	];
	if (baseDir) args.push("--incremental-basedir=" + baseDir);
	return args;
}

// prepareArgs — the --prepare steps of the MariaDB incremental procedure:
//   full  : --prepare --apply-log-only --target-dir=<full>
//   incr  : --prepare --apply-log-only --target-dir=<base> --incremental-dir=<incr>
//   close : --prepare                 --target-dir=<base>   (final, consistent)
function prepareArgs(baseDir, incrDir, final) {
	const args = ["--prepare", "--target-dir=" + baseDir];
	if (incrDir) args.push("--incremental-dir=" + incrDir);
	if (!final) args.push("--apply-log-only");
	return args;
}

function runTool(name, args, runAsMysql) {
	const spec = { binaryPath: name, arguments: args };
	if (runAsMysql) {
		spec.user = MYSQL_USER;
		spec.group = MYSQL_GROUP;
	}
	return process.run({ process: spec });
}

// sqlDumpArgs — deliberately absent. See the header: the managed path is the
// physical hot-backup tool only, never a logical dump.

// runS3Upload — aws s3 cp the artifact dir (only when a real backup exists).
function runS3Upload(backupDir, ts) {
	if (!MARIADB_BACKUP_S3_BUCKET) return false;
	if (!fs.which("aws")) {
		// Loud, not silent: a configured bucket that never receives a backup is
		// worse than no upload config at all.
		log.warn(
			"MARIADB_BACKUP_S3_BUCKET is set but the aws CLI is not in this image; skipping S3 upload",
		);
		return false;
	}
	const args = ["s3", "cp", backupDir, "s3://" + MARIADB_BACKUP_S3_BUCKET + "/" + ts + "/", "--recursive", "--region=" + MARIADB_BACKUP_S3_REGION];
	if (MARIADB_BACKUP_S3_ENDPOINT) args.push("--endpoint-url=" + MARIADB_BACKUP_S3_ENDPOINT);
	try {
		const code = runTool("aws", args, false);
		if (code === 0) {
			log.info("Backup uploaded to S3");
			return true;
		}
		log.warn("S3 upload failed (code=" + code + ")");
	} catch (e) {
		log.warn("S3 upload failed: " + e.message);
	}
	return false;
}

// runSftpUpload — scp -r the artifact dir (only when no S3 upload happened).
function runSftpUpload(backupDir) {
	if (!MARIADB_BACKUP_SFTP_HOST) return false;
	if (!fs.which("scp")) {
		log.warn(
			"MARIADB_BACKUP_SFTP_HOST is set but scp is not in this image; skipping SFTP upload",
		);
		return false;
	}
	const args = ["-r"];
	if (MARIADB_BACKUP_SFTP_KEY) args.push("-i", MARIADB_BACKUP_SFTP_KEY);
	if (MARIADB_BACKUP_SFTP_PORT && MARIADB_BACKUP_SFTP_PORT !== "22") args.push("-P", MARIADB_BACKUP_SFTP_PORT);
	args.push(backupDir, MARIADB_BACKUP_SFTP_USER + "@" + MARIADB_BACKUP_SFTP_HOST + ":" + MARIADB_BACKUP_SFTP_DEST + "/");
	try {
		const code = runTool("scp", args, false);
		if (code === 0) {
			log.info("Backup uploaded to SFTP");
			return true;
		}
		log.warn("SFTP upload failed (code=" + code + ")");
	} catch (e) {
		log.warn("SFTP upload failed: " + e.message);
	}
	return false;
}

// ---------------------------------------------------------------------------
// Retention — expire whole chains
// ---------------------------------------------------------------------------

// retentionCleanup — remove chains whose base is older than the retention
// window, as a unit: a base is never removed while its incrementals remain,
// since base + applied incrementals form one restore image. The newest chain is
// always kept, however old it is, so an idle server never ends up with zero
// backups. Never throws: retention must not fail a backup cycle.
function retentionCleanup(now) {
	try {
		const retentionDays = parseInt(MARIADB_BACKUP_RETENTION_DAYS, 10);
		const cutoff = now - retentionDays * 86400000;
		const all = chains();

		for (let i = 0; i < all.length; i++) {
			if (i === all.length - 1) continue; // keep the newest chain
			const chain = all[i];
			const when = parseTs(chain.base.ts);
			if (when === null || when.getTime() >= cutoff) continue;
			for (const member of chain.members) {
				fs.removeAll(MARIADB_BACKUP_DIR + "/" + member.name);
				log.info("Removed expired backup (" + chain.base.name + " chain): " + member.name);
			}
		}

		// Orphaned incrementals and legacy pre-chain artifacts / dump files,
		// governed by the same age cut-off.
		const members = {};
		for (const chain of chains()) {
			for (const m of chain.members) members[m.name] = true;
		}
		for (const entry of fs.readDir(MARIADB_BACKUP_DIR)) {
			let when = null;
			const a = parseArtifact(entry);
			if (a) {
				if (a.type !== "incr" || members[entry]) continue;
			} else {
				const legacy =
					/^backup_(\d{8}_\d{6})$/.exec(entry) || /^full_backup_(\d{8}_\d{6})\.sql$/.exec(entry);
				if (!legacy) continue;
				when = parseTs(legacy[1]);
			}
			if (when === null) when = a === null ? null : parseTs(a.ts);
			if (when === null || when.getTime() >= cutoff) continue;
			fs.removeAll(MARIADB_BACKUP_DIR + "/" + entry);
			log.info("Removed expired backup: " + entry);
		}
	} catch (e) {
		log.warn("Retention cleanup failed (non-fatal): " + e.message);
	}
}

// ---------------------------------------------------------------------------
// The backup cycle
// ---------------------------------------------------------------------------

// runBackup — one full or incremental cycle. `type` is "full" or "incr";
// called by the scheduler.every JS callbacks in runtime.js (one node per type,
// each on its own cron expression). Self-gates on the socket and on a lockfile
// so an overlapping tick skips instead of corrupting a chain.
function runBackup(type) {
	const kind = type === "incr" ? "incr" : "full";

	if (!fs.exists(MARIADB_SOCKET)) {
		log.warn("MariaDB socket not ready; skipping " + kind + " backup");
		return;
	}
	if (fs.exists(BACKUP_LOCK)) {
		log.warn("Another backup cycle is running; skipping " + kind + " backup");
		return;
	}
	fs.write(BACKUP_LOCK, kind + " " + new Date().toISOString() + "\n", { mode: 0o644 });

	try {
		const owner = MYSQL_USER + ":" + MYSQL_GROUP;
		fs.ensureDir(MARIADB_BACKUP_DIR, { mode: 0o750, owner: owner });

		// Incrementals need an open base; without one there is nothing to
		// extend, so fail loudly rather than silently taking a weaker backup.
		let base = null;
		if (kind === "incr") {
			base = latestBase();
			if (base === null) {
				log.error("No open base backup to extend; skipping incremental (take a full first)");
				return;
			}
		}

		const method = MARIADB_BACKUP_METHOD;
		if (!fs.which(method)) {
			log.error(
				"Backup method " +
					method +
					" is not available in this image; backup NOT taken (no dump fallback — dump tooling is left to the user)",
			);
			return;
		}

		const now = new Date();
		const stamp = timestamp(now);
		const artifact = { type: kind, ts: stamp, name: kind + "_" + stamp };
		const dir = MARIADB_BACKUP_DIR + "/" + artifact.name;
		const baseDir = base === null ? null : MARIADB_BACKUP_DIR + "/" + base.name;

		log.info(
			"Starting " + kind + " backup: " + dir + (baseDir ? " (base=" + base.name + ")" : ""),
		);
		fs.ensureDir(dir, { mode: 0o750, owner: owner });

		// 1) Take the backup.
		const code = runTool(method, backupArgs(dir, baseDir), true);
		if (code !== 0 || fs.readDir(dir).length === 0) {
			log.error("Backup command failed (code=" + code + "); backup NOT taken");
			fs.removeAll(dir);
			return;
		}

		// 2) Prepare it (apply-log-only) — the roll-forward step. For an
		// incremental this applies into the base, so the base stays the single
		// accumulated restore image.
		const pCode =
			kind === "full"
				? runTool(method, prepareArgs(dir, null, false), true)
				: runTool(method, prepareArgs(baseDir, dir, false), true);
		if (pCode !== 0) {
			log.error(
				"Prepare failed (code=" +
					pCode +
					"); discarding " +
					artifact.name +
					(base === null ? "" : " (chain left at " + base.name + ")"),
			);
			fs.removeAll(dir);
			return;
		}
		fs.write(markerPath(artifact, MARKER_PREPARED), "apply-log-only\n", { mode: 0o644 });
		log.info("Prepared (apply-log-only" + (base === null ? "" : " -> " + base.name) + "): " + artifact.name);

		// 3) Upload the new artifact when a transport is configured.
		if (!runS3Upload(dir, artifact.ts)) {
			runSftpUpload(dir);
		}

		// 4) A new full supersedes the previous chain: close it with the final
		// prepare so that chain is a fully consistent image.
		if (kind === "full") {
			closeFinishedChains(artifact.name, method);
		}

		retentionCleanup(now);
		log.info("Backup cycle completed: " + artifact.name);
	} finally {
		fs.remove(BACKUP_LOCK);
	}
}

// closeFinishedChains — run the final (non apply-log-only) prepare on the base
// of every chain except the newest, making those chains consistent so a restore
// needs no further roll-forward. Idempotent: closed chains are skipped.
function closeFinishedChains(newestBaseName, method) {
	const all = chains();
	for (let i = 0; i < all.length - 1; i++) {
		const base = all[i].base;
		if (base.name === newestBaseName || isClosed(base)) continue;
		const baseDir = MARIADB_BACKUP_DIR + "/" + base.name;
		const code = runTool(method, prepareArgs(baseDir, null, true), true);
		if (code !== 0) {
			log.error("Final prepare (chain close) failed for " + base.name + " (code=" + code + ")");
			continue;
		}
		fs.write(markerPath(base, MARKER_CONSISTENT), "consistent\n", { mode: 0o644 });
		log.info("Chain closed (consistent): " + base.name);
	}
}

module.exports = { runBackup, retentionCleanup, parseArtifact, chains, latestBase };
