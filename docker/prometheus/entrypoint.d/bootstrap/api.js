// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { PROMETHEUS_PORT, PROMETHEUS_DATA_DIR } = require("./env");

// checkPrometheus — Prometheus answers its own /-/ready endpoint.
function checkPrometheus() {
	return probe.http("http://127.0.0.1:" + PROMETHEUS_PORT + "/-/ready", 200);
}

// checkHealthy — the /-/healthy endpoint (liveness, distinct from readiness).
function checkHealthy() {
	return probe.http("http://127.0.0.1:" + PROMETHEUS_PORT + "/-/healthy", 200);
}

// handleHealth — composite health; only the Prometheus process is required.
function handleHealth() {
	const checks = {
		prometheus: checkPrometheus(),
		process: probe.process("prometheus"),
		disk: probe.disk(PROMETHEUS_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.prometheus, checks };
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop Prometheus, so it is reported and
// skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/prometheus/ready", () => ({ ready: checkPrometheus() }));
		api.get("/prometheus/healthy", () => ({ healthy: checkHealthy() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkPrometheus,
	checkHealthy,
};
