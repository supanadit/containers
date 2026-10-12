// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { GRAFANA_PORT, GRAFANA_DATA_DIR } = require("./env");

// checkGrafana — Grafana answers its own /api/health endpoint.
function checkGrafana() {
	return probe.http("http://127.0.0.1:" + GRAFANA_PORT + "/api/health", 200);
}

// handleHealth — composite health; only the Grafana process is required.
function handleHealth() {
	const checks = {
		grafana: checkGrafana(),
		process: probe.process("grafana"),
		disk: probe.disk(GRAFANA_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.grafana, checks };
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop Grafana, so it is reported and
// skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/grafana/health", () => ({ healthy: checkGrafana() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkGrafana,
};
