// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { GRAFANA_ALLOY_DATA_DIR, httpPort } = require("./env");

// checkAlloy — Alloy answers its own /-/ready endpoint.
function checkAlloy() {
	return probe.http("http://127.0.0.1:" + httpPort() + "/-/ready", 200);
}

// handleHealth — composite health; only the Alloy process is required.
function handleHealth() {
	const checks = {
		alloy: checkAlloy(),
		process: probe.process("alloy"),
		disk: probe.disk(GRAFANA_ALLOY_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.alloy, checks };
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop Alloy, so it is reported and skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/alloy/ready", () => ({ ready: checkAlloy() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkAlloy,
};
