// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { GRAFANA_MIMIR_DATA_DIR, MIMIR_HTTP_PORT } = require("./env");

// checkMimir — Mimir answers its own /ready endpoint.
function checkMimir() {
	return probe.http("http://127.0.0.1:" + MIMIR_HTTP_PORT + "/ready", 200);
}

function handleHealth() {
	const checks = {
		mimir: checkMimir(),
		process: probe.process("mimir"),
		disk: probe.disk(GRAFANA_MIMIR_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.mimir, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/mimir/ready", () => ({ ready: checkMimir() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkMimir,
};
