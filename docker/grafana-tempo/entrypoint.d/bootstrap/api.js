// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { GRAFANA_TEMPO_DATA_DIR, GRAFANA_TEMPO_LISTEN_PORT_HTTP } = require("./env");

// checkTempo — Tempo answers its own /ready endpoint.
function checkTempo() {
	return probe.http("http://127.0.0.1:" + GRAFANA_TEMPO_LISTEN_PORT_HTTP + "/ready", 200);
}

function handleHealth() {
	const checks = {
		tempo: checkTempo(),
		process: probe.process("tempo"),
		disk: probe.disk(GRAFANA_TEMPO_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.tempo, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/tempo/ready", () => ({ ready: checkTempo() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkTempo,
};
