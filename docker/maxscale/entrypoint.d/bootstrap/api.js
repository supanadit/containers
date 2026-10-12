// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { MAXSCALE_DATA_DIR, MAXSCALE_REST_PORT } = require("./env");

// checkMaxScale — the MaxScale REST API accepts TCP.
function checkMaxScale() {
	return probe.tcp("127.0.0.1", parseInt(MAXSCALE_REST_PORT, 10));
}

function handleHealth() {
	const checks = {
		maxscale: checkMaxScale(),
		process: probe.process("maxscale"),
		disk: probe.disk(MAXSCALE_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.maxscale, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/maxscale/health", () => ({ healthy: checkMaxScale() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkMaxScale,
};
