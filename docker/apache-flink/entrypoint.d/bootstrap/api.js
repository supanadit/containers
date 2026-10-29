// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { FLINK_DATA_DIR, CONFIG_REST_PORT } = require("./env");

// checkFlink — the JobManager answers its own REST /overview endpoint.
function checkFlink() {
	return probe.http("http://127.0.0.1:" + CONFIG_REST_PORT + "/overview", 200);
}

function handleHealth() {
	const checks = {
		jobmanager: checkFlink(),
		process: probe.process("jobmanager") || probe.process("taskmanager"),
		disk: probe.disk(FLINK_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.jobmanager, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/flink/overview", () => ({ healthy: checkFlink() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkFlink,
};
