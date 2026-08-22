// cluster.js — port of utils/cluster.sh: cluster-role detection helpers used to
// gate sshd, backups, and pgBackRest stanza initialization.
const { env, probe } = require("ezx");
const { PG_USER, PG_DB, PG_PORT, REPL_ROLE, CITUS_ENABLE, CITUS_ROLE, PATRONI_ENABLE, PGBACKREST_ENABLE } = require("./env");

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
	if (env.isTruthy("HA_MODE_NATIVE_OR_FORCE_PRIMARY")) return true;
	// Fallback: check pg_is_in_recovery via psql.
	return probe.exec(
		"/bin/sh",
		"-c",
		"PGPASSWORD='" + (env.get("POSTGRES_PASSWORD") || "") + "' psql -h " +
			env.get("POSTGRES_HOST", "127.0.0.1") + " -p " + PG_PORT + " -U " + PG_USER +
			" -d " + env.get("POSTGRES_DB", PG_DB) +
			" -tA -c 'select pg_is_in_recovery();' | grep -q f",
	);
}

// determinePgbackrestMode — primary / standby-ssh / standby-skip / disabled.
// Mirrors cluster.sh:determine_pgbackrest_mode.
function determinePgbackrestMode() {
	if (!PGBACKREST_ENABLE) return "disabled";
	if (isPrimaryRole()) return "primary";
	// Replica with a configured primary host (SSH standby backup) vs skip.
	const primaryHost = env.get("PGBACKREST_PRIMARY_HOST");
	const primaryPath = env.get("PGBACKREST_PRIMARY_PATH");
	if (primaryHost || primaryPath) return "standby-ssh";
	return "standby-skip";
}

module.exports = { isPrimaryRole, determinePgbackrestMode };