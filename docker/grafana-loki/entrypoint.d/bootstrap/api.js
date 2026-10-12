// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { GRAFANA_LOKI_DATA_DIR, GRAFANA_LOKI_LISTEN_PORT_HTTP } = require("./env");

// checkLoki — Loki answers its own /ready endpoint.
function checkLoki() {
	return probe.http("http://127.0.0.1:" + GRAFANA_LOKI_LISTEN_PORT_HTTP + "/ready", 200);
}

function handleHealth() {
	const checks = {
		loki: checkLoki(),
		process: probe.process("loki"),
		disk: probe.disk(GRAFANA_LOKI_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.loki, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/loki/ready", () => ({ ready: checkLoki() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkLoki,
};
