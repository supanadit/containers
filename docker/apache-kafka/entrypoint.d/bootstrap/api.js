// api.js — operator-facing API routes + composite health checks, served on the
// shared ezx health server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, scheduler, log } = require("ezx");
const { KAFKA_DATA_DIR } = require("./env");
const { readyProbe, brokerListener, controllerListener } = require("./runtime");

// checkKafka — the broker/controller answers its own readiness command.
function checkKafka() {
	const p = readyProbe();
	return probe.exec(...p.exec);
}

// checkProcess — a JVM running the Kafka server class.
function checkProcess() {
	return probe.process("kafka.Kafka") || probe.process("kafka-server-start");
}

// checkPort — the primary client-facing listener accepts TCP.
function checkPort() {
	const l = brokerListener() || controllerListener();
	if (!l) return false;
	const host = l.host && l.host !== "0.0.0.0" && l.host !== "::" ? l.host : "127.0.0.1";
	return probe.tcp(host, parseInt(l.port, 10));
}

// checkDisk — the data mount has at least 10% and 100MB free.
function checkDisk() {
	return probe.disk(KAFKA_DATA_DIR, 10, 100);
}

// handleHealth — composite health; only the main program (Kafka) is required.
function handleHealth() {
	const checks = {
		kafka: checkKafka(),
		process: checkProcess(),
		port: checkPort(),
		disk: checkDisk(),
		zombies: probe.zombies() === 0,
	};
	return { healthy: checks.kafka, checks };
}

// registerOpsRoutes — bind operator routes on the shared health server. When
// EZX_HEALTH_ADDR is unset the registration throws; that must not stop the
// broker, so it is reported and skipped.
function registerOpsRoutes() {
	try {
		api.get("/health/comprehensive", () => handleHealth());
		api.post("/backup/trigger", () => ({ triggered: scheduler.trigger("kafka-config-backup") }));
		api.get("/backup/status", () => scheduler.status("kafka-config-backup"));
	} catch (e) {
		log.warn("Could not register operator routes (no health server?): " + e.message);
	}
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkKafka,
	checkProcess,
	checkPort,
	checkDisk,
};
