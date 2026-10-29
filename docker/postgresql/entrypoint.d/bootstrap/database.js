// database.js — init/02-database + runtime restore: initdb, superuser password,
// replication user, HA clone, cluster verification, and pgBackRest restore.
// Mirrors bash init/02-database.sh and startup.sh:perform_pgbackrest_restore.
const { env, fs, editor, process, log } = require("ezx");
const {
	PGDATA,
	PGRUN,
	PG_USER,
	PG_GROUP,
	PG_PORT,
	PG_PASS,
	STANZA,
	PATRONI_ENABLE,
	PGBACKREST_ENABLE,
	HA_MODE,
	REPL_ROLE,
	REPL_USER,
	REPL_PASSWORD,
	REPL_SLOT,
	PRIMARY_HOST,
	PRIMARY_PORT,
	RESTORE_SENTINEL,
	RESTORE_COMPLETE_MARK,
} = require("./env");

const TIMEOUT_CHANGE_PASSWORD = env.int("TIMEOUT_CHANGE_PASSWORD", 5);

// Run a one-shot command as the postgres user with an args array (no shell).
function runPg(argv, name) {
	return process.run({
		name: name || "pg",
		process: {
			binaryPath: argv[0],
			arguments: argv.slice(1),
			user: PG_USER,
			group: PG_GROUP,
		},
	});
}

function clusterExists() {
	return ["PG_VERSION", "postgresql.conf", "pg_hba.conf"].some((f) =>
		fs.exists(PGDATA + "/" + f),
	);
}

// Restore request fingerprint + one-shot marker.
//
// PGBACKREST_RESTORE is an environment variable, so it cannot be cleared by the
// entrypoint. If it is left in a deployment manifest (a very easy mistake after
// an incident), every subsequent container start would restore again -- moving
// PGDATA aside and rolling the database back to that same point, silently
// destroying anything written since. To prevent that, a successful restore
// writes a marker INSIDE PGDATA (the one path that is persistent and survives
// pod recreation) recording exactly what was requested. A later start with the
// identical request skips the restore; a different request (a new target) still
// runs.
const RESTORE_MARK_FILE = "/.container-restore.complete";

function restoreRequestFingerprint() {
	return JSON.stringify({
		type: env.get("PGBACKREST_RESTORE_TYPE", ""),
		target: env.get("PGBACKREST_RESTORE_TARGET", ""),
		xid: env.get("PGBACKREST_RESTORE_TARGET_XID", ""),
		lsn: env.get("PGBACKREST_RESTORE_TARGET_LSN", ""),
		name: env.get("PGBACKREST_RESTORE_TARGET_NAME", ""),
		set: env.get("PGBACKREST_RESTORE_SET", ""),
		timeline: env.get("PGBACKREST_RESTORE_TARGET_TIMELINE", ""),
		action: env.get("PGBACKREST_RESTORE_TARGET_ACTION", ""),
	});
}

function markRestoreFulfilled() {
	const mark = PGDATA + RESTORE_MARK_FILE;
	fs.write(mark, restoreRequestFingerprint() + "\n", { mode: 0o600 });
	fs.chown(mark, PG_USER + ":" + PG_GROUP);
	fs.chmod(mark, 0o600);
}

function isRestoreRequested() {
	if (!env.bool("PGBACKREST_RESTORE")) return false;
	const mark = PGDATA + RESTORE_MARK_FILE;
	if (fs.exists(mark)) {
		const prev = (editor.open(mark).read() || "").trim();
		if (prev === restoreRequestFingerprint()) {
			log.warn(
				"PGBACKREST_RESTORE=true is still set but this exact restore was already " +
					"performed; skipping so the running cluster is not rolled back again. " +
					"Remove PGBACKREST_RESTORE from the deployment to silence this.",
			);
			return false;
		}
	}
	return true;
}

// parseDuration — "0", "30s", "15m", "24h", "7d", "2w" (bare number = seconds).
function parseDuration(raw, envName) {
	const v = String(raw == null ? "" : raw).trim().toLowerCase();
	if (v === "") throw new Error(envName + " is empty (use 0 to disable, or e.g. 7d)");
	const m = /^([0-9]+(?:\.[0-9]+)?)\s*(s|m|h|d|w)?$/.exec(v);
	if (!m)
		throw new Error(
			envName + ": invalid duration '" + raw + "' (use 0, 30s, 15m, 24h, 7d, 2w)",
		);
	const unit = { s: 1, m: 60, h: 3600, d: 86400, w: 604800 }[m[2] || "s"];
	return Math.floor(parseFloat(m[1]) * unit);
}

// pgbackrestInfo — inspect the repository. Returns the parsed
// `info --output=json` payload, or null when the repo cannot be inspected.
function pgbackrestInfo() {
	const res = process.capture({
		process: {
			binaryPath: "pgbackrest",
			arguments: [
				"--config=/etc/pgbackrest.conf",
				"--stanza=" + STANZA,
				"--log-level-console=off",
				"info",
				"--output=json",
			],
			user: PG_USER,
			group: PG_GROUP,
			filterEnvPattern: ["^PGBACKREST_"],
			check: false,
		},
	});
	if (res.code !== 0) return null;
	let parsed;
	try {
		parsed = JSON.parse(res.stdout);
	} catch {
		return null;
	}
	// An uninspectable repo yields `[]` (or a stanza we do not recognise). `[]`
	// is truthy in JS, so it must be rejected explicitly -- otherwise it looks
	// like "a stanza with no backups" instead of "could not inspect".
	if (!Array.isArray(parsed) || parsed.length === 0) return null;
	return parsed;
}

// guardRestoreAge — refuse to restore from a stale backup.
//
// The failure mode this exists for: pgBackRest is disabled for months, the
// repository still holds an old backup set, and then a restore (often from a
// forgotten PGBACKREST_RESTORE=true) replaces a healthy live cluster with
// months-old data. The default is therefore safe out of the box: the backup set
// that would actually be restored must be no older than
// PGBACKREST_RESTORE_MAX_BACKUP_AGE (default 7d). Set it to 0 to disable.
//
// MUST run before prepareRestoreEnvironment(), which empties PGDATA -- a refused
// restore has to leave the current data untouched.
function guardRestoreAge() {
	// Treat an empty/whitespace value as "unset" so a K8s configmap with a blank
	// entry still gets the safe default rather than an error.
	const rawMaxAge = env.get("PGBACKREST_RESTORE_MAX_BACKUP_AGE");
	const maxAge = parseDuration(
		rawMaxAge == null || String(rawMaxAge).trim() === "" ? "7d" : rawMaxAge,
		"PGBACKREST_RESTORE_MAX_BACKUP_AGE",
	);

	const info = pgbackrestInfo();
	if (!info) {
		// Repository could not be inspected. A restore would almost certainly fail
		// anyway, and blocking a genuine disaster recovery is worse than the
		// residual risk, so continue -- loudly.
		log.warn(
			"could not inspect the pgBackRest repository to verify backup age; proceeding with the restore",
		);
		return;
	}

	const stanza = (info || [])[0] || {};
	const backups = stanza.backup || [];
	if (backups.length === 0)
		throw new Error(
			"PGBACKREST_RESTORE is set but stanza '" + STANZA + "' contains no backups",
		);

	const requestedSet = env.get("PGBACKREST_RESTORE_SET", "");
	const wanted =
		requestedSet && requestedSet !== "latest"
			? backups.find((b) => b.label === requestedSet)
			: backups[backups.length - 1];
	if (!wanted)
		throw new Error(
			"PGBACKREST_RESTORE_SET='" + requestedSet + "' not found in stanza '" + STANZA + "'",
		);

	const stopEpoch = (wanted.timestamp && wanted.timestamp.stop) || 0;
	const ageSec = Math.max(0, Math.floor(Date.now() / 1000) - stopEpoch);
	const ageDays = (ageSec / 86400).toFixed(2);
	log.warn(
		"restore candidate: set " +
			wanted.label +
			" (" +
			wanted.type +
			"), taken " +
			ageSec +
			"s ago (~" +
			ageDays +
			"d)" +
			(maxAge > 0 ? ", age limit " + maxAge + "s" : ", age limit disabled"),
	);

	if (maxAge > 0 && ageSec > maxAge)
		throw new Error(
			"REFUSED to restore: the backup that would be used ('" +
				wanted.label +
				"') is " +
				ageDays +
				" days old, older than PGBACKREST_RESTORE_MAX_BACKUP_AGE=" +
				env.get("PGBACKREST_RESTORE_MAX_BACKUP_AGE", "7d") +
				". Restoring would replace current data with stale data, so the current " +
				"cluster has been left untouched. If this is intentional, raise the limit " +
				"or set PGBACKREST_RESTORE_MAX_BACKUP_AGE=0.",
		);
}

// guardNoSilentInitdb — refuse to create a fresh empty cluster over an existing
// stanza. See the call site in initdb() for why. Bypass with
// PGBACKREST_INITDB_FORCE=true when a deliberate rebuild is intended.
function guardNoSilentInitdb() {
	if (!PGBACKREST_ENABLE) return;
	if (env.bool("PGBACKREST_INITDB_FORCE")) {
		log.warn(
			"PGBACKREST_INITDB_FORCE=true: allowing a fresh empty cluster even though stanza '" +
				STANZA + "' may already contain backups",
		);
		return;
	}
	const info = pgbackrestInfo();
	if (!info) return; // cannot inspect the repo -> do not block a first boot
	const backups = ((info || [])[0] || {}).backup || [];
	if (backups.length === 0) return;
	throw new Error(
		"REFUSED to initialise an empty cluster: PGDATA is empty but stanza '" +
			STANZA +
			"' already contains " +
			backups.length +
			" backup(s) in the repository (newest: " +
			backups[backups.length - 1].label +
			"). This normally means the data volume was deleted or wiped. Creating a fresh " +
			"cluster would serve an empty database and make those backups unrestorable. " +
			"Restore instead: set PGBACKREST_RESTORE=true (optionally with " +
			"PGBACKREST_RESTORE_TYPE / PGBACKREST_RESTORE_TARGET / PGBACKREST_RESTORE_SET). " +
			"To deliberately build a new empty cluster anyway, set " +
			"PGBACKREST_INITDB_FORCE=true.",
	);
}

function cleanupStaleRestoreMarkers() {
	fs.ensureDir(PGRUN, { mode: 0o755 });
	if (fs.exists(RESTORE_SENTINEL)) fs.remove(RESTORE_SENTINEL);
}

function prepareRestoreEnvironment() {
	const owner = PG_USER + ":" + PG_GROUP;
	if (fs.exists(PGDATA) && fs.readDir(PGDATA).length > 0) {
		const backupPath = PGDATA + ".pre-restore." + Math.floor(Date.now() / 1000);
		try {
			// Not a mount point: move the cluster aside on the same filesystem
			// so the previous data survives as a local safeguard.
			fs.rename(PGDATA, backupPath);
			fs.chownRecursive(backupPath, owner);
			log.warn("Moved existing data directory to " + backupPath);
		} catch {
			// PGDATA is a mount point (Kubernetes PVC, docker volume, bind
			// mount), so the directory itself can be neither renamed nor
			// unlinked ("device or resource busy"). Empty it in place.
			// Do NOT copy it aside first: the copy would land on the
			// container's writable layer, which is ephemeral and can fill up
			// on a real database. The repository is the safeguard here.
			log.warn(
				"PGDATA is a mount point; emptying it in place (no local safeguard copy is possible)",
			);
			clearDataDir();
		}
	}
	fs.ensureDir(PGDATA, { mode: 0o700 });
	fs.chown(PGDATA, owner);
	fs.chmod(PGDATA, 0o700);
}

function markRestorePending() {
	fs.ensureDir(PGRUN, { mode: 0o755 });
	fs.write(RESTORE_SENTINEL, "requested_at=" + new Date().toISOString() + "\n", { mode: 0o600 });
}

function configureReplicaAppname() {
	const autoConf = PGDATA + "/postgresql.auto.conf";
	if (!fs.exists(autoConf)) return;
	// goja_nodejs has no require("os"); use the HOSTNAME env var (set by the
	// container runtime) like the original bash did.
	const explicit = env.get("REPLICATION_APPNAME", "");
	const appname = explicit || env.get("HOSTNAME", "");
	const e = editor.open(autoConf);
	const lines = e.readLines();
	let found = false;
	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		if (/^\s*primary_conninfo\s*=/.test(line)) {
			found = true;
			// An explicitly configured REPLICATION_APPNAME must win over an inherited
			// one: pgpool matches a standby by comparing its backend_application_name
			// against this value in pg_stat_replication, so a stale name (a bare
			// hostname, or 'walreceiver') silently disables auto_failback,
			// replication_state and delay_threshold_by_time. Without an explicit
			// name, leave whatever is already there (previous behaviour).
			if (/application_name=/.test(line)) {
				if (!explicit) return;
				// [^'\s]* so only the value is replaced, not the closing quote.
				lines[i] = line.replace(/application_name=[^'\s]*/, "application_name=" + appname);
				continue;
			}
			// Append application_name inside the trailing quote, preserving
			// host/port/user/password (matches the original bash sed).
			lines[i] = line.replace(/'\s*$/, " application_name=" + appname + "'");
		}
	}
	if (!found) {
		lines.push("primary_conninfo = 'application_name=" + appname + "'");
	}
	e.writeLines(lines);
}

// clearDataDir — empty PGDATA without unlinking the directory itself. The
// data dir is a volume mount point in most deployments; removing it fails
// with "device or resource busy" (the old fs.removeAll(PGDATA) error path
// crashed the whole bootstrap instead of reporting pg_basebackup failure).
function clearDataDir() {
	for (const entry of fs.readDir(PGDATA)) fs.removeAll(PGDATA + "/" + entry);
}

function clonePrimary() {
	if (!PRIMARY_HOST) throw new Error("PRIMARY_HOST required for replica");
	if (fs.readDir(PGDATA).length > 0)
		throw new Error("Data directory is not empty. Cannot clone primary.");

	const argv = [
		"pg_basebackup",
		"-h",
		PRIMARY_HOST,
		"-p",
		PRIMARY_PORT,
		"-U",
		REPL_USER || "replicator",
		"-D",
		PGDATA,
		"-Fp",
		"-Xs",
		"-R",
	];
	// Reserve this standby's physical slot on the primary for the duration of
	// the clone (bash 02-database.sh:clone_primary -S "${REPLICATION_SLOT}").
	// Without it, WAL generated during a long base backup can be recycled
	// before the standby finishes streaming it.
	if (REPL_SLOT) argv.push("-S", REPL_SLOT);
	// The primary creates REPLICATION_SLOTS in a oneshot right after it first
	// becomes ready, and compose/k8s start replicas the moment the primary
	// reports healthy — so a -S clone can race the slot creation and lose
	// ("replication slot ... does not exist"). Retry a few times with a
	// pause; a genuinely broken clone fails identically each time.
	let code = 1;
	for (let attempt = 1; attempt <= 3; attempt++) {
		code = process.run({
			process: {
				binaryPath: argv[0],
				arguments: argv.slice(1),
				environment: ["PGPASSWORD=" + REPL_PASSWORD],
				user: PG_USER,
				group: PG_GROUP,
			},
		});
		if (code === 0) break;
		if (attempt < 3) {
			clearDataDir();
			log.warn("pg_basebackup failed (attempt " + attempt + "/3); retrying in 5s");
			process.run({ process: { binaryPath: "sleep", arguments: ["5"], user: PG_USER, group: PG_GROUP } });
		}
	}
	if (code !== 0) {
		clearDataDir();
		throw new Error("pg_basebackup failed");
	}
	configureReplicaAppname();
}

// Temp-server helper: write a minimal config, start postgres on port 5433,
// run the SQL as postgres, stop, then secure-clean the config.
function runOnTempServer(sql, name) {
	const cfg = fs.tempFile("/tmp", "pg_tmp");
	fs.write(
		cfg,
		"listen_addresses = 'localhost'\nport = 5433\nunix_socket_directories = '" +
			PGDATA +
			"'\npassword_encryption = scram-sha-256\n",
		{ mode: 0o644 },
	);
	try {
		if (
			process.run({
				process: {
					binaryPath: "pg_ctl",
					arguments: ["-D", PGDATA, "-o", "--config-file=" + cfg, "-s", "start"],
					user: PG_USER,
					group: PG_GROUP,
				},
			}) !== 0
		) {
			throw new Error("Failed to start postgres for " + name);
		}
		process.run({ process: { binaryPath: "sleep", arguments: ["2"], user: PG_USER, group: PG_GROUP } });
		const res = process.run({
			process: {
				binaryPath: "timeout",
				arguments: [String(TIMEOUT_CHANGE_PASSWORD), "psql", "-h", "localhost", "-p", "5433", "-U", "postgres", "-d", "postgres", "-c", sql],
				user: PG_USER,
				group: PG_GROUP,
			},
		});
		process.run({ process: { binaryPath: "pg_ctl", arguments: ["-D", PGDATA, "-s", "stop"], user: PG_USER, group: PG_GROUP } });
		if (res !== 0) throw new Error("Failed to run " + name + " SQL");
	} finally {
		// Note: no secure shred in ezx 0.0.1; fs.remove leaves freed blocks.
		fs.remove(cfg);
	}
}

function setPassword() {
	if (!PG_PASS) return;
	runOnTempServer("ALTER USER postgres PASSWORD '" + String(PG_PASS).replace(/'/g, "''") + "';", "pw");
}

function createReplicationUser() {
	if (HA_MODE !== "native" || REPL_ROLE !== "primary") return;
	runOnTempServer(
		"CREATE USER " +
			(REPL_USER || "replicator") +
			" REPLICATION LOGIN PASSWORD '" +
			String(REPL_PASSWORD || "replicator_password").replace(/'/g, "''") +
			"';",
		"repl-user",
	);
}

function verifyClusterIntegrity() {
	for (const f of ["PG_VERSION", "postgresql.conf", "pg_hba.conf", "pg_ident.conf"]) {
		if (!fs.exists(PGDATA + "/" + f)) throw new Error("Required cluster file missing: " + f);
	}
	for (const d of ["base", "global", "pg_xact", "pg_wal"]) {
		if (!fs.exists(PGDATA + "/" + d)) throw new Error("Required cluster directory missing: " + d);
	}
	const cfg = fs.tempFile("/tmp", "pg_test");
	fs.write(
		cfg,
		"listen_addresses = ''\nport = 5433\nunix_socket_directories = '" + PGDATA + "'\n",
		{ mode: 0o644 },
	);
	try {
		if (
			process.run({
				process: {
					binaryPath: "pg_ctl",
					arguments: ["-D", PGDATA, "-o", "--config-file=" + cfg, "-s", "start"],
					user: PG_USER,
					group: PG_GROUP,
				},
			}) !== 0
		) {
			throw new Error("Failed to start cluster for testing");
		}
		process.run({ process: { binaryPath: "sleep", arguments: ["2"], user: PG_USER, group: PG_GROUP } });
		const status = process.run({ process: { binaryPath: "pg_ctl", arguments: ["-D", PGDATA, "status"], user: PG_USER, group: PG_GROUP } });
		process.run({ process: { binaryPath: "pg_ctl", arguments: ["-D", PGDATA, "-s", "stop"], user: PG_USER, group: PG_GROUP } });
		if (status !== 0) throw new Error("Cluster failed to start properly");
	} finally {
		fs.remove(cfg);
	}
}

function initdb() {
	// Clear stale restore markers before any logic (bash 02-database.sh:39).
	cleanupStaleRestoreMarkers();

	if (isRestoreRequested()) {
		if (!PGBACKREST_ENABLE)
			throw new Error("PGBACKREST_RESTORE=true requires PGBACKREST_ENABLE=true");
		// Age guard first: it must be able to refuse while PGDATA is still intact
		// (prepareRestoreEnvironment would otherwise empty it and then bail).
		guardRestoreAge();
		prepareRestoreEnvironment();
		markRestorePending();
		log.info("Restore requested; waiting for runtime restore");
		return;
	}

	if (clusterExists()) {
		log.info("Cluster exists, skipping initdb");
		// A replica cloned before REPLICATION_APPNAME was configured -- or cloned by
		// an image that predates this call -- has no application_name in
		// primary_conninfo, so it advertises PostgreSQL's built-in default
		// ("walreceiver"). pgpool identifies a standby by matching its
		// backend_application_name against that value in pg_stat_replication, so
		// skipping this here means the appname of an existing replica can never be
		// corrected: clonePrimary() was the only caller, and it only runs on a
		// fresh clone. Guarded to replicas so a primary never gains a stray
		// primary_conninfo.
		if (HA_MODE === "native" && REPL_ROLE === "replica") {
			configureReplicaAppname();
		}
		return;
	}
	if (PATRONI_ENABLE) return;
	if (HA_MODE === "native" && REPL_ROLE === "replica") {
		clonePrimary();
		return;
	}

	// Last line of defence for the primary: never silently initialise a brand-new
	// empty cluster when the repository already holds backups for this stanza.
	// An empty PGDATA plus a populated stanza is the signature of a deleted or
	// wiped data volume, and initialising here does two damaging things:
	//   1. the application gets an empty database that reports healthy;
	//   2. the stanza-init that follows rebinds the stanza to the new system-id,
	//      after which the existing backups can no longer be restored
	//      ("[075] ... is from a prior version of PostgreSQL").
	guardNoSilentInitdb();

	const argv = [
		"initdb",
		"--auth=trust",
		"--username=postgres",
		"--encoding=UTF-8",
		"--locale=C",
	];
	const initdbArgs = env.get("POSTGRES_INITDB_ARGS");
	if (initdbArgs) argv.push(...initdbArgs.split(/\s+/));
	const waldir = env.get("POSTGRES_INITDB_WALDIR");
	if (waldir) argv.push("--waldir=" + waldir);
	argv.push("--pgdata=" + PGDATA);
	if (process.run({ process: { binaryPath: argv[0], arguments: argv.slice(1), user: PG_USER, group: PG_GROUP } }) !== 0)
		throw new Error("initdb failed");
	fs.chmod(PGDATA, 0o700);
	if (fs.exists(PGDATA + "/PG_VERSION")) fs.chmod(PGDATA + "/PG_VERSION", 0o644);

	setPassword();
	createReplicationUser();
	verifyClusterIntegrity();
}

// Build pgBackRest restore args from env (full parity with
// start/perform_pgbackrest_restore).
function restoreArgs() {
	const args = ["--config=/etc/pgbackrest.conf", "--stanza=" + STANZA, "restore"];
	const opt = (v, f) => {
		if (v) args.push("--" + f + "=" + v);
	};
	const optList = (v, f) => {
		if (!v) return;
		for (const item of v.split(",").filter(Boolean)) args.push("--" + f + "=" + item.trim());
	};
	const flag = (v, f) => {
		if (env.bool(v)) args.push("--" + f);
	};
	// pgBackRest exposes a single --target whose meaning is selected by --type
	// (default|immediate|xid|name|lsn|time). There are no --target-xid,
	// --target-lsn, --target-name, --target-immediate, --recovery-target-tli or
	// --recovery-target-action options (all verified against 2.56.0), so the
	// per-type env vars are translated into --type/--target instead. An explicit
	// PGBACKREST_RESTORE_TYPE wins.
	let restoreType = env.get("PGBACKREST_RESTORE_TYPE");
	let restoreTarget = env.get("PGBACKREST_RESTORE_TARGET");
	for (const [envName, type] of [
		["PGBACKREST_RESTORE_TARGET_XID", "xid"],
		["PGBACKREST_RESTORE_TARGET_LSN", "lsn"],
		["PGBACKREST_RESTORE_TARGET_NAME", "name"],
	]) {
		const v = env.get(envName);
		if (v) {
			restoreType = restoreType || type;
			restoreTarget = restoreTarget || v;
		}
	}
	if (env.bool("PGBACKREST_RESTORE_TARGET_IMMEDIATE")) restoreType = restoreType || "immediate";
	opt(restoreType, "type");
	opt(restoreTarget, "target");
	opt(env.get("PGBACKREST_RESTORE_TARGET_TIMELINE"), "target-timeline");
	opt(env.get("PGBACKREST_RESTORE_TARGET_ACTION"), "target-action");
	opt(env.get("PGBACKREST_RESTORE_SET"), "set");
	optList(env.get("PGBACKREST_RESTORE_TABLESPACE_MAP"), "tablespace-map");
	opt(env.get("PGBACKREST_RESTORE_TABLESPACE_MAP_ALL"), "tablespace-map-all");
	flag("PGBACKREST_RESTORE_LINK_ALL", "link-all");
	optList(env.get("PGBACKREST_RESTORE_LINK_MAP"), "link-map");
	optList(env.get("PGBACKREST_RESTORE_DB_INCLUDE"), "db-include");
	optList(env.get("PGBACKREST_RESTORE_DB_EXCLUDE"), "db-exclude");
	optList(env.get("PGBACKREST_RESTORE_RECOVERY_OPTION"), "recovery-option");
	opt(env.get("PGBACKREST_RESTORE_ARCHIVE_MODE"), "archive-mode");
	if (env.bool("PGBACKREST_RESTORE_DELTA", true)) args.push("--delta");
	flag("PGBACKREST_RESTORE_FORCE", "force");
	const extra = env.get("PGBACKREST_RESTORE_EXTRA_OPTS");
	if (extra) args.push(...extra.split(/\s+/).filter(Boolean));
	return args;
}

function performRestore() {
	if (!PGBACKREST_ENABLE)
		throw new Error("PGBACKREST_RESTORE requires PGBACKREST_ENABLE");
	if (!fs.exists("/etc/pgbackrest.conf"))
		throw new Error("pgbackrest configuration /etc/pgbackrest.conf not found");
	fs.ensureDir(PGDATA, { mode: 0o700 });
	fs.chown(PGDATA, PG_USER + ":" + PG_GROUP);
	fs.chmod(PGDATA, 0o700);

	// Replace the shell's generate_clean_env_command (env -u PGBACKREST_*).
	const argv = ["pgbackrest"].concat(restoreArgs());
	if (
		process.run({
			process: {
				binaryPath: argv[0],
				arguments: argv.slice(1),
				filterEnvPattern: ["^PGBACKREST_"],
				user: PG_USER,
				group: PG_GROUP,
			},
		}) !== 0
	)
		throw new Error("pgBackRest restore failed");

	fs.ensureDir(PGRUN, { mode: 0o755 });
	if (fs.exists(RESTORE_SENTINEL)) fs.remove(RESTORE_SENTINEL);
	fs.write(RESTORE_COMPLETE_MARK, "restored_at=" + new Date().toISOString() + "\n", { mode: 0o600 });

	// One-shot semantics: record what was restored so a leftover
	// PGBACKREST_RESTORE=true does not restore again on the next start.
	markRestoreFulfilled();
}

module.exports = {
	runPg,
	clusterExists,
	clonePrimary,
	setPassword,
	createReplicationUser,
	initdb,
	performRestore,
	restoreArgs,
	isRestoreRequested,
	markRestorePending,
	cleanupStaleRestoreMarkers,
};
