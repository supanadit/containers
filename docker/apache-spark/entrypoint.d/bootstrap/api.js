// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const { SPARK_DATA_DIR, SPARK_MASTER_WEBUI_PORT } = require("./env");

// checkMaster — the Spark master answers its Web UI on the master webui port.
function checkMaster() {
	return probe.http("http://127.0.0.1:" + SPARK_MASTER_WEBUI_PORT + "/", 200);
}

function handleHealth() {
	const checks = {
		master: checkMaster(),
		process: probe.process("spark") || probe.process("Master") || probe.process("Worker"),
		disk: probe.disk(SPARK_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.master, checks };
}

function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/spark/master", () => ({ healthy: checkMaster() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkMaster,
};
