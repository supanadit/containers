// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { PYROSCOPE_DATA_DIR } = require("./env");
const { pyroscopeHTTPPort } = require("./runtime");

// checkPyroscope — Pyroscope answers its own /ready endpoint.
function checkPyroscope() {
	return probe.http("http://127.0.0.1:" + pyroscopeHTTPPort() + "/ready", 200);
}

function handleHealth() {
	const checks = {
		pyroscope: checkPyroscope(),
		process: probe.process("pyroscope"),
		disk: probe.disk(PYROSCOPE_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.pyroscope, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/pyroscope/ready", () => ({ ready: checkPyroscope() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkPyroscope,
};
