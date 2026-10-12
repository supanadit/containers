// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { THANOS_COMPONENT, THANOS_DATA_DIR, httpPort } = require("./env");

// checkThanos — the component answers its own /-/ready endpoint.
function checkThanos() {
	return probe.http("http://127.0.0.1:" + httpPort() + "/-/ready", 200);
}

// handleHealth — composite health; only the Thanos process is required.
function handleHealth() {
	const checks = {
		thanos: checkThanos(),
		process: probe.process("thanos"),
		disk: probe.disk(THANOS_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.thanos, component: THANOS_COMPONENT, checks };
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop the component, so it is reported and
// skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/thanos/ready", () => ({ ready: checkThanos(), component: THANOS_COMPONENT }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkThanos,
};
