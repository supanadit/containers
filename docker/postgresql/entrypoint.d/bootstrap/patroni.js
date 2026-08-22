// patroni.js — Patroni role-change pgBackRest reconfiguration, driven from
// within the single bootstrap. A scheduled curl child (runtime.js) POSTs to
// /patroni/role-check on the shared health server; the handler detects a
// promote/demote and regenerates /etc/pgbackrest.conf (add/remove pg2-*,
// flip backup-standby). Replaces the deleted bash Patroni callback without any
// external executable.
const { env, fs, editor, api, log } = require("ezx");
const { PGBACKREST_CONF, PGBACKREST_ENABLE, PG_USER, PG_GROUP, PATRONI_ENABLE } = require("./env");
const { backupStandby } = require("./config");
const { isPrimaryRole } = require("./cluster");

let lastRole = null;

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

// registerPatroniRoutes — bind the role-check handler on the shared health
// server. Called from main.js before chain.run (handlers run on HTTP
// goroutines while the chain supervises).
function registerPatroniRoutes() {
	if (!PATRONI_ENABLE || !PGBACKREST_ENABLE) return;
	if (!env.get("EZX_HEALTH_ADDR")) return;
	api.post("/patroni/role-check", () => checkRole());
}

// roleCheckUrl — target URL for the scheduled curl child (parses the port from
// EZX_HEALTH_ADDR, e.g. ":8008" or "0.0.0.0:8008").
function roleCheckUrl() {
	const addr = env.get("EZX_HEALTH_ADDR", "");
	const m = /:(\d+)$/.exec(addr);
	const port = m ? m[1] : "8080";
	return "http://127.0.0.1:" + port + "/patroni/role-check";
}

module.exports = { checkRole, registerPatroniRoutes, roleCheckUrl, regenerateForPrimary, regenerateForReplica };