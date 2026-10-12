// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { ZOOKEEPER_DATA_DIR, ZOOKEEPER_CLIENT_PORT } = require("./env");

// checkZookeeper — ZooKeeper accepts TCP on its client port.
function checkZookeeper() {
	return probe.tcp("127.0.0.1", parseInt(ZOOKEEPER_CLIENT_PORT, 10));
}

function handleHealth() {
	const checks = {
		zookeeper: checkZookeeper(),
		process: probe.process("zookeeper") || probe.process("QuorumPeerMain"),
		disk: probe.disk(ZOOKEEPER_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.zookeeper, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/zookeeper/health", () => ({ healthy: checkZookeeper() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkZookeeper,
};
