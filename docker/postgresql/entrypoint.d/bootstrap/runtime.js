// runtime.js — runtime/startup: supervise the database + sidecar process tree
// in a single chain. ezx stays PID 1 and supervises the postgres/patroni root
// and every dependent (stanza/userlist/repl-user init one-shots, pgbouncer,
// sshd, scheduled backups) concurrently, forwarding signals, reaping zombies,
// and draining on SIGTERM. The Patroni role-check runs as a scheduler.every
// JS callback in api.js (no curl child). Scheduled pgBackRest backup
// node-builders are absorbed here from the old backup.js.
//
// ezx 0.3.0+: the dependency graph is expressed as a flat `nodes` list with
// explicit `dependsOn` / `dependsOnEdges` instead of the recursive `roots` /
// `children` tree. Init steps (stanza-init, replication-user, userlist-init)
// are `oneshot: true` nodes that run to completion before their dependents
// proceed; long-running sidecars (pgbouncer, sshd) and scheduled nodes
// (backup-full/diff/incr, patroni-role-check) share the same graph.
//
// Per-service log rotation (`log.stdout: "file"` on each `process`) writes
// every sidecar's stdout/stderr to its own file under /opt/containers/logs/
// with size-based rotation, so a noisy pgbouncer cannot drown out postgres
// (or vice versa) on the shared parent stdout.
const { env, fs, chain, scheduler } = require("ezx");
const {
	PGDATA,
	PGRUN,
	PGLOG,
	PG_USER,
	PG_GROUP,
	PG_PORT,
	PG_PASS,
	PATRONI_ENABLE,
	PGBOUNCER_ENABLE,
	PGBACKREST_ENABLE,
	PATRONI_CONF,
	PGBOUNCER_INI,
	PGBOUNCER_USERLIST,
	REPL_ROLE,
	REPL_USER,
	REPL_PASSWORD,
	HA_MODE,
	STANZA,
	PG_READY_MAX_ATTEMPTS,
	PGBACKREST_AUTO,
	PGBACKREST_AUTO_FIRST_INCR_DELAY,
	CITUS_ENABLE,
	CITUS_ROLE,
} = require("./env");
const { postgresFiles } = require("./config");
const { roleCheckNode } = require("./api");

// logFor — build a per-service rotated log block. maxBytes is tuned per
// service: 50 MiB for the heavy database + sidecars that absorb real traffic,
// 10 MiB for the lighter init oneshots. Path is /opt/containers/logs/<name>.log
// with .1 ... .maxBackups shifted files.
function logFor(name, maxBytes, maxBackups) {
	return {
		stdout: "file",
		stderr: "file",
		filePath: PGLOG + "/" + name + ".log",
		maxBytes: maxBytes,
		maxBackups: maxBackups,
	};
}

// pgLog — default log block for the postgres/patroni root and long-running
// sidecars (50 MiB × 5 rotations).
const pgLog = (name) => logFor(name, 50 * 1024 * 1024, 5);
// shotLog — default log block for init oneshots (10 MiB × 3 rotations; a
// oneshot is short-lived, so a smaller window is fine and keeps the dir tidy).
const shotLog = (name) => logFor(name, 10 * 1024 * 1024, 3);

// databaseName — root node name in buildDatabaseNode ("patroni" in Patroni
// mode, "postgres" otherwise). Flat-DAG dependents target this name in their
// dependsOnEdges.
const databaseName = () => (PATRONI_ENABLE ? "patroni" : "postgres");

// readyOn — express "wait for the database to be ready" on the flat DAG.
// Replaces the legacy `needParentReady: true` parent-child sugar with an
// explicit edge.
const readyOn = () => ({ name: databaseName(), waitFor: "ready" });

// userlistInit — query pg_shadow for the postgres password hash and write
// pgbouncer userlist.txt (bash startup.sh:285-302). Uses process.capture to
// fetch the hash, then writes the file directly in JS (no shell).
function userlistInit() {
	if (!PGBOUNCER_ENABLE) return null;
	const pgUser = env.get("POSTGRES_USER", "postgres");
	const pgPass = PG_PASS;
	const escapedUser = pgUser.replace(/"/g, '\\"');
	// Build the userlist line inside onStart (after postgres is ready).
	const build = () => {
		if (!pgPass) {
			return '"' + pgUser + '" ""';
		}
		const sql = "SELECT passwd FROM pg_shadow WHERE usename = '" + String(pgUser).replace(/'/g, "''") + "';";
		const res = process.capture({
			process: {
				binaryPath: "psql",
				arguments: ["-v", "ON_ERROR_STOP=1", "-tA", "-h", PGRUN, "-d", "postgres", "-U", pgUser, "-c", sql],
				environment: ["PGPASSWORD=" + pgPass],
				user: PG_USER,
				group: PG_GROUP,
				check: false,
			},
		});
		if (res.code !== 0) {
			log.error("[pgbouncer] failed to fetch password hash (code=" + res.code + ")");
			return null;
		}
		return '"' + escapedUser + '" "' + res.stdout.trim() + '"';
	};
	const write = () => {
		const line = build();
		if (line === null) return;
		fs.write(PGBOUNCER_USERLIST, line + "\n");
		fs.chown(PGBOUNCER_USERLIST, PG_USER + ":" + PG_GROUP);
		fs.chmod(PGBOUNCER_USERLIST, 0o600);
	};
	return {
		name: "pgbouncer-userlist",
		oneshot: true,
		dependsOnEdges: [readyOn()],
		onStart: write,
		log: shotLog("pgbouncer-userlist"),
	};
}

// stanzaInit — create/upgrade the pgBackRest stanza once postgres is ready
// (bash startup.sh:initialize_pgbackrest_stanza + cluster.sh modes). Only runs
// on the primary (or Patroni) — a replica has no primary cluster to back up, so
// stanza-create would fail with "unable to find primary cluster".
function stanzaInit() {
	if (!PGBACKREST_ENABLE) return null;
	// Native-HA replica: skip stanza init (no primary cluster here).
	if (HA_MODE === "native" && REPL_ROLE === "replica") return null;
	const stanzaArgs = ["--config=/etc/pgbackrest.conf", "--stanza=" + STANZA];
	// Run pgbackrest with standard options (user/group/env filtering).
	const runPgbackrest = (subcommand) =>
		process.run({
			process: {
				binaryPath: "pgbackrest",
				arguments: stanzaArgs.concat([subcommand]),
				user: PG_USER,
				group: PG_GROUP,
				filterEnvPattern: ["^PGBACKREST_"],
			},
		});
	// Initialize stanza: try create, fall back to upgrade, then check.
	const initStanza = () => {
		let code = runPgbackrest("stanza-create");
		if (code !== 0) {
			log.info("[pgbackrest] stanza-create failed (code=" + code + "), trying stanza-upgrade");
			code = runPgbackrest("stanza-upgrade");
		}
		if (code === 0) {
			runPgbackrest("check");
		}
	};
	// In Patroni mode the role is dynamic: a node may start as a replica where
	// stanza-create legitimately fails ("unable to find primary cluster"). Mark
	// it optional so it doesn't kill the container; the primary's stanza-init
	// succeeds and the role-check callback handles promotion.
	return {
		name: "pgbackrest-stanza-init",
		oneshot: true,
		dependsOnEdges: [readyOn()],
		optional: PATRONI_ENABLE,
		onStart: initStanza,
		log: shotLog("pgbackrest-stanza-init"),
	};
}

// replUser — create the replication user for native-HA primary (bash
// startup.sh:create_replication_user). Connects via the local unix socket as
// the postgres superuser (POSTGRES_PASSWORD), matching the original bash which
// used peer/trust auth on the socket — NOT the replicator's password.
function replUser() {
	if (HA_MODE !== "native" || REPL_ROLE !== "primary" || !REPL_USER) return null;
	if (!REPL_PASSWORD) throw new Error("REPLICATION_PASSWORD required for native-HA primary");
	const pgUser = env.get("POSTGRES_USER", "postgres");
	const pgPass = env.get("POSTGRES_PASSWORD", "");
	// SQL: idempotent CREATE ROLE with replication. Password/role names are
	// escaped for SQL literal context (single-quote doubling).
	const escapedRole = String(REPL_USER).replace(/'/g, "''");
	const escapedPass = String(REPL_PASSWORD).replace(/'/g, "''");
	const sql =
		"DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '" + escapedRole + "') THEN " +
		"CREATE ROLE " + REPL_USER + " REPLICATION LOGIN PASSWORD '" + escapedPass + "'; " +
		"END IF; END $$;";
	const create = () => {
		const code = process.run({
			process: {
				binaryPath: "psql",
				arguments: ["-h", PGRUN, "-p", PG_PORT, "-U", pgUser, "-d", "postgres", "-c", sql],
				environment: ["PGPASSWORD=" + pgPass],
				user: PG_USER,
				group: PG_GROUP,
			},
		});
		if (code !== 0) {
			log.error("[replication] failed to create replication role (code=" + code + ")");
		}
	};
	return {
		name: "replication-user",
		oneshot: true,
		dependsOnEdges: [readyOn()],
		onStart: create,
		log: shotLog("replication-user"),
	};
}

// pgbouncerNode — supervised long-running pgbouncer sidecar (restart always).
// The pgbouncer.ini is generated by the postgresFiles FileProvision during
// chain.run (gated on PGBOUNCER_ENABLE), so no existence check here — it runs
// before provisioning and would fail spuriously. Runs pgbouncer in foreground
// (no -d): daemon mode forks and the parent exits 0 immediately, which would
// make ezx restart-loop on the still-held socket.
function pgbouncerNode() {
	if (!PGBOUNCER_ENABLE) return null;
	return {
		name: "pgbouncer",
		dependsOnEdges: [readyOn()],
		optional: true,
		process: {
			binaryPath: "pgbouncer",
			arguments: [PGBOUNCER_INI],
			user: PG_USER,
			group: PG_GROUP,
			log: pgLog("pgbouncer"),
		},
		restart: { mode: "always", backoff: 2e9 },
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
	};
}

// sshdNode — supervised long-running sshd sidecar on the primary (restart
// always). Gated on REPL_ROLE because this is evaluated at tree-build time,
// before postgres is up; native replicas are never primary. Runs sshd with -D
// (don't daemonize): without it sshd forks into the background and the parent
// exits 0 immediately, making ezx restart-loop on the held port 22.
function sshdNode() {
	if (REPL_ROLE === "replica") return null;
	if (!fs.exists("/usr/sbin/sshd")) return null;
	return {
		name: "sshd",
		dependsOnEdges: [readyOn()],
		optional: true,
		process: {
			binaryPath: "/usr/sbin/sshd",
			arguments: ["-D"],
			log: pgLog("sshd"),
		},
		restart: { mode: "always", backoff: 2e9 },
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
	};
}

function startSleep() {
	chain.run({
		nodes: [
			{
				name: "sleep",
				process: {},
				restart: { mode: "always", backoff: 1000 * 1e6 },
			},
		],
	});
}

// Backup flags from env, mirroring the shell scheduler's run_backup (no bash).
function backupFlags(type) {
	const args = [
		"--config=/etc/pgbackrest.conf",
		"--stanza=" + STANZA,
		"backup",
		"--type=" + type,
	];
	const flag = (envName, arg) => {
		if (env.bool(envName)) args.push(arg);
	};
	// Default-true flags: env.bool honors the shell's default-true semantics.
	const flagDefault = (envName, arg, def) => {
		if (env.bool(envName, def)) args.push(arg);
	};
	flag("PGBACKREST_BACKUP_START_FAST", "--start-fast");
	flag("PGBACKREST_BACKUP_STOP_AUTO", "--stop-auto");
	flagDefault("PGBACKREST_BACKUP_VERIFY", "--verify", true);
	flag("PGBACKREST_BACKUP_CHECKSUM_PAGE", "--checksum-page");
	flagDefault("PGBACKREST_BACKUP_ARCHIVE_CHECK", "--archive-check", true);
	flag("PGBACKREST_BACKUP_ARCHIVE_COPY", "--archive-copy");
	flag("PGBACKREST_BACKUP_EXPIRE_AUTO", "--expire-auto");
	flagDefault("PGBACKREST_BACKUP_RESUME", "--resume", true);
	flagDefault(
		"PGBACKREST_BACKUP_ARCHIVE_MISSING_RETRY",
		"--archive-missing-retry",
		true,
	);
	for (const x of (env.get("PGBACKREST_BACKUP_EXCLUDE") || "")
		.split(/[, ]+/)
		.filter(Boolean))
		args.push("--exclude=" + x);
	for (const a of (env.get("PGBACKREST_BACKUP_ANNOTATION") || "")
		.split(/[, ]+/)
		.filter(Boolean))
		args.push("--annotation=" + a);
	return args;
}

// Primary-role gate (postgres-specific, composed from generic probes):
// Patroni REST /master then /leader → 2xx when primary; Citus role env; else
// pg_is_in_recovery()=f via psql. The scheduled node skips ticks while the
// gate fails, so replicas never run backups.
function primaryGate() {
	if (PATRONI_ENABLE) {
		const base = env.get("PATRONI_REST_URL", "http://localhost:8008");
		// /master OR /leader — composed via probe.any (no shell)
		return {
			any: [
				{ type: "http", http: { url: base + "/master", expectStatus: 200 } },
				{ type: "http", http: { url: base + "/leader", expectStatus: 200 } },
			],
		};
	}
	if (CITUS_ENABLE) {
		return CITUS_ROLE === "coordinator"
			? { type: "exec", exec: ["true"] }
			: { type: "exec", exec: ["false"] };
	}
	// Native: pg_is_in_recovery() returns "f" for primary, "t" for replica.
	// Use execExpect to gate on stdout (no shell pipe to grep).
	return {
		type: "exec",
		exec: [
			"psql", "-qtAX",
			"-U", PG_USER,
			"-h", "127.0.0.1", "-p", PG_PORT,
			"-d", env.get("POSTGRES_DB", "postgres"),
			"-c", "select pg_is_in_recovery();",
		],
		env: ["PGPASSWORD=" + (env.get("POSTGRES_PASSWORD") || "")],
		execExpect: "f",
	};
}

// A scheduled pgBackRest backup node: ezx runs the node's Process on the cron
// tick, gated on primary-role, and skips duplicate ticks within a minute.
function backupNode(type, defaultCron) {
	return {
		name: "backup-" + type,
		dependsOnEdges: [readyOn()],
		optional: true,
		process: {
			binaryPath: "pgbackrest",
			arguments: backupFlags(type),
			user: PG_USER,
			group: PG_GROUP,
			// Replace the shell's generate_clean_env_command (env -u PGBACKREST_*).
			filterEnvPattern: ["^PGBACKREST_"],
			log: pgLog("backup-" + type),
		},
		scheduler: scheduler.build({
			schedule: {
				expression: env.get(
					"PGBACKREST_AUTO_" + type.toUpperCase() + "_CRON",
					defaultCron,
				),
				timezone: env.get("PGBACKREST_AUTO_TIMEZONE", "UTC"),
			},
			initialDelay: PGBACKREST_AUTO_FIRST_INCR_DELAY * 1e9,
			minInterval: 60e9, // one backup per minute, matching the shell dedup
			// PGBACKREST_AUTO_PRIMARY_ONLY (default true) gates backups on the
			// primary role; set false to also run on replicas (SSH standby).
			gate: env.bool("PGBACKREST_AUTO_PRIMARY_ONLY", true) ? primaryGate() : null,
		}),
	};
}

// Scheduled backup nodes on the flat DAG (dependsOn edges so backups start
// only after the DB is up, replacing PGBACKREST_PARENT_PID).
function backupNodes() {
	if (!PGBACKREST_ENABLE || !PGBACKREST_AUTO) return [];
	return [
		backupNode("full", "0 2 * * *"),
		backupNode("diff", "20 2,8,14,20 * * *"),
		backupNode("incr", "*/15 * * * *"),
	];
}

// buildDatabaseNode — construct the postgres/patroni root node. readiness
// gates downstream dependents; health wires /readyz from the same probe.
function buildDatabaseNode() {
	const mainProcess = PATRONI_ENABLE
		? {
				binaryPath: "patroni",
				arguments: [PATRONI_CONF],
				user: PG_USER,
				group: PG_GROUP,
				log: pgLog("patroni"),
			}
		: {
				binaryPath: env.get("POSTGRES_BIN", "postgres"),
				arguments: ["-D", PGDATA],
				user: PG_USER,
				group: PG_GROUP,
				// Strip PGBACKREST_* from postgres's env so the archive_command
				// child (pgbackrest archive-push) doesn't inherit them as config
				// overrides (pgbackrest maps PGBACKREST_REPO_S3_* to unindexed
				// options and errors). Matches the original bash where postgres
				// never had these vars.
				filterEnvPattern: ["^PGBACKREST_"],
				log: pgLog("postgres"),
			};

	const node = {
		name: databaseName(),
		process: mainProcess,
		files: postgresFiles(),
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP", "SIGUSR1", "SIGUSR2"],
		shutdown: { timeout: -1, forceKill: false },
	};

	// Readiness probe gating downstream dependents (postgres must accept
	// connections before stanza-init/userlist/pgbouncer/sshd start). Mirrors
	// the bash wait_for_postgresql_ready loop. Set unconditionally — node.health
	// (the /readyz HTTP surface) is only wired when EZX_HEALTH_ADDR is set.
	node.readiness = {
		type: "exec",
		exec: ["pg_isready", "-h", PGRUN, "-p", PG_PORT, "-U", PG_USER],
		interval: 1e9,
		timeout: 5e9,
		maxAttempts: PG_READY_MAX_ATTEMPTS,
	};

	// The health server always runs (ezx defaults EZX_HEALTH_ADDR to :8080),
	// so wire node.health unconditionally to drive /readyz from the readiness
	// probe. Backup manual-trigger + role-check routes are registered by
	// api.js:registerOpsRoutes (called from main.js before chain.run).
	node.health = { readyProbe: node.readiness };

	return node;
}

function startDatabase() {
	const database = buildDatabaseNode();
	const roleCheck = roleCheckNode();

	// Flat DAG: every node is a sibling. Dependents express "wait for postgres
	// to be ready" via dependsOnEdges so the explicit wait mode is visible at
	// each edge instead of being inherited from a parent in a nested tree.
	const nodes = [database];
	for (const n of [stanzaInit(), replUser(), userlistInit(), pgbouncerNode(), sshdNode(), roleCheck]) {
		if (n) nodes.push(n);
	}
	for (const n of backupNodes()) nodes.push(n);

	chain.run({ nodes: nodes });
}

module.exports = {
	startPgbouncer: pgbouncerNode,
	startSshd: sshdNode,
	startSleep,
	startDatabase,
	buildDatabaseNode,
	backupFlags,
	primaryGate,
	backupNode,
	backupNodes,
	logFor,
	pgLog,
	shotLog,
};
