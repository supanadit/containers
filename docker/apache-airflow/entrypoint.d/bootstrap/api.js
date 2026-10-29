// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { AIRFLOW_DATA_DIR, AIRFLOW_PORT } = require("./env");

// checkAirflow — the API server accepts TCP on its port.
function checkAirflow() {
	return probe.tcp("127.0.0.1", parseInt(AIRFLOW_PORT, 10));
}

function handleHealth() {
	const checks = {
		airflow: checkAirflow(),
		process: probe.process("airflow"),
		disk: probe.disk(AIRFLOW_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.airflow, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/airflow/health", () => ({ healthy: checkAirflow() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkAirflow,
};
