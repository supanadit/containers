// routes.js — operator-facing API routes on the shared health server
// (EZX_HEALTH_ADDR), registered from main.js before chain.run. Handlers run on
// HTTP goroutines while the chain supervises, so they can safely use editor /
// process / probe. Replaces the deleted standalone healthcheck.js and
// sync-reload.js scripts — no second bootstrap, no launchers.
const { env, fs, editor, api, process, probe } = require("ezx");
const {
	PGDATA,
	PG_USER,
	PG_GROUP,
	PG_PORT,
	PG_DB,
	PATRONI_ENABLE,
	PGBOUNCER_ENABLE,
} = require("./env");

// sync-reload — rewrite synchronous_standby_names and reload without restart
// (port of misc/pg-reload-sync-config.sh). POST body/query:
//   mode=true&count=1&replicas=pg2  |  mode=false
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

	const p = process.spawn({
		name: "pg-reload",
		process: {
			binaryPath: "pg_ctl",
			arguments: ["-D", PGDATA, "reload"],
			user: PG_USER,
			group: PG_GROUP,
		},
	});
	p.start([]);
	const code = p.wait();
	if (code !== 0) throw new Error("pg_ctl reload failed (code=" + code + ")");
	return { ok: true, synchronous_standby_names: mode === "true" ? (count && replicas ? "ANY " + count + " (" + replicas + ")" : "*") : "(removed)" };
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
	return { healthy: Object.values(checks).every(Boolean), checks };
}

// registerOpsRoutes — bind operator routes; no-op without EZX_HEALTH_ADDR.
function registerOpsRoutes() {
	if (!env.get("EZX_HEALTH_ADDR")) return;
	api.post("/sync-reload", () => handleSyncReload());
	api.get("/health/comprehensive", () => handleHealth());
}

module.exports = { registerOpsRoutes, handleSyncReload, handleHealth };