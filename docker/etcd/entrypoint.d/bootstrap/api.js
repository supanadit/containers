// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { ETCD_DATA_DIR } = require("./env");
const { etcdClientPort } = require("./runtime");

// checkEtcd — the endpoint answers on its client port.
function checkEtcd() {
	return probe.tcp("127.0.0.1", parseInt(etcdClientPort(), 10));
}

// handleHealth — composite health; only the etcd process is required.
function handleHealth() {
	const checks = {
		etcd: checkEtcd(),
		process: probe.process("etcd"),
		disk: probe.disk(ETCD_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.etcd, checks };
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop etcd, so it is reported and skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/etcd/health", () => ({ healthy: checkEtcd() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkEtcd,
};
