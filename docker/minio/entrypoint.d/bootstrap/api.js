// api.js — operator-facing routes + composite health on the shared ezx health
// server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, log } = require("ezx");
const {
	MINIO_DATA_DIR,
	MINIO_ADDRESS,
	MINIO_CONSOLE_ADDRESS,
	MINIO_DISTRIBUTED_MODE_ENABLED,
	portOf,
} = require("./env");
const { driveArgs } = require("./runtime");

// checkMinioReady — MinIO's own readiness endpoint (checks all drives).
function checkMinioReady() {
	return probe.http("http://127.0.0.1:" + portOf(MINIO_ADDRESS) + "/minio/health/ready", 200);
}

// checkMinioLive — MinIO's liveness endpoint (does not check drives).
function checkMinioLive() {
	return probe.http("http://127.0.0.1:" + portOf(MINIO_ADDRESS) + "/minio/health/live", 200);
}

// checkConsole — the console listener accepts TCP (when enabled).
function checkConsole() {
	if (!MINIO_CONSOLE_ADDRESS) return true;
	return probe.tcp("127.0.0.1", parseInt(portOf(MINIO_CONSOLE_ADDRESS), 10));
}

// handleHealth — composite health; only the MinIO server is required.
function handleHealth() {
	const checks = {
		minio: checkMinioReady(),
		live: checkMinioLive(),
		console: checkConsole(),
		process: probe.process("minio"),
		disk: probe.disk(MINIO_DATA_DIR, 10, 100),
		zombies: probe.zombies() === 0,
	};
	return {
		healthy: checks.minio,
		distributed: MINIO_DISTRIBUTED_MODE_ENABLED,
		drives: driveArgs(),
		checks,
	};
}

// registerOpsRoutes — bind operator routes. When EZX_HEALTH_ADDR is unset the
// registration throws; that must not stop MinIO, so it is reported and skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.get("/minio/ready", () => ({ ready: checkMinioReady() }));
		api.get("/minio/live", () => ({ live: checkMinioLive() }));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkMinioReady,
	checkMinioLive,
	checkConsole,
};
