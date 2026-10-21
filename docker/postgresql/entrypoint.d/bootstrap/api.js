// api.js — operator-facing API routes + Patroni role-change pgBackRest
// reconfiguration, consolidated from routes.js + patroni.js + backup.js's route
// registration. All handlers live on the shared health server (EZX_HEALTH_ADDR)
// and run on HTTP goroutines while the chain supervises. The Patroni role check
// runs as a scheduler.every JS callback (replacing the old scheduled curl child
// + HTTP route) so a promote/demote regenerates pgbackrest.conf without any
// external callback executable. The role-check node expresses its dependency on
// the postgres/patroni root via `dependsOnEdges: [{ name: "postgres", waitFor:
// "ready" }]` (the flat-DAG convention; equivalent to the legacy `needParentReady: true`).
const { env, fs, editor, api, process, probe, shell, scheduler, log } = require("ezx");
const {
	PGDATA,
	PG_USER,
	PG_GROUP,
	PG_PORT,
	PG_DB,
	PATRONI_ENABLE,
	PGBOUNCER_ENABLE,
	PGBACKREST_ENABLE,
	PGBACKREST_CONF,
	STANZA,
	PGBACKREST_AUTO,
	CITUS_ENABLE,
	CITUS_ROLE,
} = require("./env");
const { backupStandby } = require("./config");

let lastRole = null;

// isPrimaryRole — true when this node is the cluster primary.
// Patroni: REST /master or /leader returns 2xx. Citus: coordinator only.
// Native: pg_is_in_recovery() returns "f".
function isPrimaryRole() {
	if (PATRONI_ENABLE) {
		const base = env.get("PATRONI_REST_URL", "http://localhost:8008");
		if (probe.http(base + "/master", 200)) return true;
		if (probe.http(base + "/leader", 200)) return true;
		return false;
	}
	if (CITUS_ENABLE) {
		return CITUS_ROLE === "coordinator";
	}
	if (env.bool("HA_MODE_NATIVE_OR_FORCE_PRIMARY")) return true;
	// Fallback: check pg_is_in_recovery via psql (args array, no shell).
	const res = process.capture({
		process: {
			binaryPath: "psql",
			arguments: [
				"-h",
				env.get("POSTGRES_HOST", "127.0.0.1"),
				"-p",
				PG_PORT,
				"-U",
				PG_USER,
				"-d",
				env.get("POSTGRES_DB", PG_DB),
				"-tA",
				"-c",
				"select pg_is_in_recovery();",
			],
			environment: ["PGPASSWORD=" + (env.get("POSTGRES_PASSWORD") || "")],
			check: false,
		},
	});
	return res.code === 0 && res.stdout.includes("f");
}

function rewriteConfig(removePg2, standbyMode) {
	if (!fs.exists(PGBACKREST_CONF)) return;
	const e = editor.open(PGBACKREST_CONF);
	const content =
		e
			.read()
			.split("\n")
			.filter((l) => !/^pg2-/.test(l) && !/^backup-standby=/.test(l))
			.join("\n")
			.replace(/\n+$/, "") + "\n";
	e.replace(content + (standbyMode ? "backup-standby=" + standbyMode + "\n" : ""));
	fs.chmod(PGBACKREST_CONF, 0o640);
	fs.chown(PGBACKREST_CONF, PG_USER + ":" + PG_GROUP);
}

function regenerateForPrimary() {
	log.info("[patroni] role change: primary — removing pg2-host settings");
	rewriteConfig(true, "n");
}

function regenerateForReplica() {
	const primaryPath = env.get("PGBACKREST_PRIMARY_PATH");
	const primaryHost = env.get("PGBACKREST_PRIMARY_HOST", env.get("PRIMARY_HOST"));
	if (!primaryPath || !primaryHost) {
		log.warn("[patroni] replica role but no PGBACKREST_PRIMARY_PATH/HOST; leaving pgbackrest.conf");
		return;
	}
	const standbyMode = backupStandby(env.get("PGBACKREST_BACKUP_STANDBY")) || "y";
	const primaryPort = env.get("PGBACKREST_PRIMARY_PORT", env.get("PRIMARY_PORT", "5432"));
	const sshPort = env.get("PGBACKREST_PRIMARY_SSH_PORT", "22");
	const sshUser = env.get("PGBACKREST_PRIMARY_SSH_USER", "postgres");
	const sshKey = env.get("PGBACKREST_PRIMARY_SSH_KEY_FILE", "/home/postgres/.ssh/id_rsa");

	log.info("[patroni] role change: replica — adding pg2-host for standby backup");
	rewriteConfig(false, standbyMode);
	editor
		.open(PGBACKREST_CONF)
		.append(
			"pg2-host=" + primaryHost + "\n" +
				"pg2-host-port=" + sshPort + "\n" +
				"pg2-host-user=" + sshUser + "\n" +
				"pg2-port=" + primaryPort + "\n" +
				"pg2-user=" + env.get("PGBACKREST_PRIMARY_USER", PG_USER) + "\n" +
				"pg2-host-key-file=" + sshKey + "\n",
		);
}

// checkRole — poll the current role and regenerate pgbackrest.conf on change.
function checkRole() {
	if (!isPrimaryRole()) {
		if (lastRole !== "replica") {
			regenerateForReplica();
			lastRole = "replica";
			return { role: "replica", changed: true };
		}
		return { role: "replica", changed: false };
	}
	if (lastRole !== "primary") {
		regenerateForPrimary();
		lastRole = "primary";
		return { role: "primary", changed: true };
	}
	return { role: "primary", changed: false };
}

// handleSyncReload — rewrite synchronous_standby_names and reload without
// restart (port of misc/pg-reload-sync-config.sh). The target value is read from
// the container environment — handlers receive no request object, so there is no
// body/query to parse:
//   SYNC_MODE=true&SYNC_COUNT=1&SYNC_REPLICAS=pg2  |  SYNC_MODE=false
function handleSyncReload() {
	const mode = env.get("SYNC_MODE", env.get("REPLICATION_SYNCHRONOUS_MODE", "true"));
	const count = env.get("SYNC_COUNT", env.get("REPLICATION_SYNCHRONOUS_COUNT", ""));
	const replicas = env.get("SYNC_REPLICAS", env.get("REPLICATION_SYNCHRONOUS_REPLICAS", ""));

	const conf = PGDATA + "/postgresql.conf";
	if (!fs.exists(conf)) throw new Error("postgresql.conf not found at " + conf);

	const e = editor.open(conf);
	if (mode === "true") {
		const ssn = count && replicas ? "ANY " + count + " (" + replicas + ")" : "*";
		e.upsert("^\\s*synchronous_standby_names\\s*=", "synchronous_standby_names = '" + ssn + "'");
	} else {
		e.remove("^\\s*synchronous_standby_names\\s*=");
	}

	const code = process.run({
		process: {
			binaryPath: "pg_ctl",
			arguments: ["-D", PGDATA, "reload"],
			user: PG_USER,
			group: PG_GROUP,
		},
	});
	if (code !== 0) throw new Error("pg_ctl reload failed (code=" + code + ")");
	return { ok: true, synchronous_standby_names: mode === "true" ? (count && replicas ? "ANY " + count + " (" + replicas + ")" : "*") : "(removed)" };
}

// inRecovery — live standby check for the /promote guard. Returns true
// (standby), false (primary), or null when the state cannot be determined
// (server unreachable, psql failed, unreadable output). Callers must treat
// null as "do not promote".
function inRecovery() {
	const res = process.capture({
		process: {
			binaryPath: "psql",
			arguments: [
				"-h",
				env.get("POSTGRES_HOST", "127.0.0.1"),
				"-p",
				PG_PORT,
				"-U",
				PG_USER,
				"-d",
				env.get("POSTGRES_DB", PG_DB),
				"-tA",
				"-c",
				"select pg_is_in_recovery();",
			],
			environment: ["PGPASSWORD=" + (env.get("POSTGRES_PASSWORD") || "")],
			check: false,
		},
	});
	if (res.code !== 0) return null;
	const out = res.stdout.trim();
	if (out === "t") return true;
	if (out === "f") return false;
	return null;
}

// refuse — uniform refusal payload for /promote. ok:false + reason, so an
// operator (or automation) always gets an explicit answer, never a silent
// no-op that looks like success.
function refuse(reason) {
	log.warn("[promote] refused: " + reason);
	return { ok: false, promoted: false, reason: reason };
}

// handlePromote — POST /promote: turn this native-HA standby into the
// primary (pg_ctl promote under the hood, ezx keeps supervising the
// postmaster). Safety first: a promote is ONE-WAY for the data dir — Postgres
// drops standby.signal, so the node comes back as a primary even if the
// REPLICATION_ROLE env flip is forgotten — and a stray call on a primary
// would be a split-brain starter. So the call is refused unless BOTH the
// bootstrap role (env) and the live server state agree this node is a
// standby:
//   1. Patroni owns promotion there — never promote behind its back.
//   2. HA_MODE must be native (nothing to promote otherwise).
//   3. REPLICATION_ROLE must be "replica" (bootstrap-time role; a node
//      started as primary is refused outright).
//   4. The live server must report pg_is_in_recovery()=t — this also catches
//      the already-promoted-then-restarted case, where the env still says
//      replica but the data dir is already a primary.
//   5. Unreachable/undeterminable state is treated as "do not promote".
function handlePromote() {
	if (PATRONI_ENABLE) {
		return refuse("promotion under Patroni is Patroni's job (PATRONI REST /fail), not /promote");
	}
	if (env.get("HA_MODE") !== "native") {
		return refuse("HA_MODE is not native; this node has no standby to promote");
	}
	const role = env.get("REPLICATION_ROLE");
	if (role !== "replica") {
		return refuse("REPLICATION_ROLE is '" + (role || "(unset)") + "', not 'replica'; refusing to promote a non-standby");
	}
	const recovery = inRecovery();
	if (recovery === null) {
		return refuse("cannot determine server state (is postgres up and reachable?); refusing to promote");
	}
	if (recovery === false) {
		return refuse("server reports it is already a primary (pg_is_in_recovery()=f); refusing");
	}
	const code = process.run({
		process: {
			binaryPath: "pg_ctl",
			arguments: ["-D", PGDATA, "promote"],
			user: PG_USER,
			group: PG_GROUP,
		},
	});
	if (code !== 0) throw new Error("pg_ctl promote failed (code=" + code + ")");
	log.warn("[promote] standby promoted to primary (new timeline)");
	return {
		ok: true,
		promoted: true,
		note: "promote is one-way: flip REPLICATION_ROLE=primary (+ REPLICATION_SLOTS, see compose ROLE SWAP) so restarts agree with the new topology; verify with SELECT pg_is_in_recovery();",
	};
}

// healthCheck — composite health probes (port of runtime/healthcheck.sh).
function checkPostgresql() {
	const host = env.get("POSTGRES_HOST", "127.0.0.1");
	return probe.tcp(host, parseInt(PG_PORT, 10)) ||
		probe.exec("pg_isready", "-h", host, "-p", PG_PORT, "-U", PG_USER, "-d", env.get("POSTGRES_DB", PG_DB));
}

function checkPatroni() {
	if (!PATRONI_ENABLE) return true;
	return probe.http(env.get("PATRONI_REST_URL", "http://localhost:8008") + "/patroni", 200);
}

function checkPgbouncer() {
	if (!PGBOUNCER_ENABLE) return true;
	const port = parseInt(env.get("PGBOUNCER_LISTEN_PORT", "6432"), 10);
	return probe.process("pgbouncer") && probe.tcp("127.0.0.1", port);
}

function checkDisk() {
	return probe.disk(PGDATA, 10, 100);
}

function checkProcess() {
	return probe.process("postgres") && probe.zombies() === 0;
}

function handleHealth() {
	const checks = {
		postgresql: checkPostgresql(),
		patroni: checkPatroni(),
		pgbouncer: checkPgbouncer(),
		disk: checkDisk(),
		process: checkProcess(),
	};
	// Only the main program determines health. Sidecars are optional.
	const main = PATRONI_ENABLE ? checks.patroni : checks.postgresql;
	return { healthy: main, checks };
}

// User-defined manual-trigger routes on the shared health server (always up
// on :8080). scheduler.trigger(name) fires a scheduled node immediately.
function registerBackupRoutes() {
	for (const type of ["full", "diff", "incr"]) {
		api.post("/backup/" + type, () => {
			const fired = scheduler.trigger("backup-" + type);
			return {
				ok: fired,
				type: type,
				inflight: scheduler.status("backup-" + type).inflight,
			};
		});
	}
	api.get("/backup/status", () => ({
		full: scheduler.status("backup-full"),
		diff: scheduler.status("backup-diff"),
		incr: scheduler.status("backup-incr"),
	}));
}

// registerRoleCheck - build the in-process Patroni role-check scheduled node
// (the approved deviation: replaces the old curl child + HTTP route). Returns
// a ProcessNode whose scheduler runs the JS callback on a cron tick; the
// orchestrator invokes the callback instead of spawning a process. Must be
// attached to the chain (runtime.js adds it as a flat-DAG sibling). gated on
// PATRONI_ENABLE && PGBACKREST_ENABLE && EZX_HEALTH_ADDR. The dependency edge
// targets "patroni" in Patroni mode and "postgres" otherwise - matching the
// root node's name in runtime.js:buildDatabaseNode.
function roleCheckNode() {
	if (!PATRONI_ENABLE || !PGBACKREST_ENABLE) return null;
	return {
		name: "patroni-role-check",
		dependsOnEdges: [{ name: PATRONI_ENABLE ? "patroni" : "postgres", waitFor: "ready" }],
		optional: true,
		// Process field removed - the scheduler callback handles all work
		scheduler: scheduler.every(env.get("PATRONI_ROLE_CHECK_CRON", "*/1 * * * *"), () => checkRole(), {
			timezone: env.get("PGBACKREST_AUTO_TIMEZONE", "UTC"),
			initialDelay: 30e9,
		}),
	};
}

// registerOpsRoutes — bind operator routes + backup routes. The role-check
// node is added to the chain by runtime.js. /promote is only registered on a
// native-HA node (404 elsewhere — a clearer signal than a guard refusal on
// nodes that can never promote); the in-handler guards then cover the
// role/state cases, including "hit while primary".
function registerOpsRoutes() {
	api.post("/sync-reload", () => handleSyncReload());
	api.get("/health/comprehensive", () => handleHealth());
	if (!PATRONI_ENABLE && env.get("HA_MODE") === "native") {
		api.post("/promote", () => handlePromote());
	}
	registerBackupRoutes();
}

module.exports = {
	registerOpsRoutes,
	registerBackupRoutes,
	roleCheckNode,
	handleSyncReload,
	handleHealth,
	handlePromote,
	inRecovery,
	checkRole,
	regenerateForPrimary,
	regenerateForReplica,
	isPrimaryRole,
};
