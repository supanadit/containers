// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { CASSANDRA_DATA_DIR, CASSANDRA_NATIVE_PORT } = require("./env");

// checkCassandra — Cassandra accepts TCP on its native (CQL) port.
function checkCassandra() {
	return probe.tcp("127.0.0.1", parseInt(CASSANDRA_NATIVE_PORT, 10));
}

function handleHealth() {
	const checks = {
		cassandra: checkCassandra(),
		process: probe.process("cassandra") || probe.process("CassandraDaemon"),
		disk: probe.disk(CASSANDRA_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.cassandra, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/cassandra/health", () => ({ healthy: checkCassandra() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkCassandra,
};
