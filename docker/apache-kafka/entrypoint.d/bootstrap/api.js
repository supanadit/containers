// api.js — operator-facing API routes + composite health checks, served on the
// shared ezx health server (EZX_HEALTH_ADDR, default :8080).
const { api, probe, scheduler, log } = require("ezx");
const { KAFKA_DATA_DIR } = require("./env");
const { readyProbe, brokerListener, controllerListener } = require("./runtime");

// listenerAddr — host/port of a listener, with a routable host.
function listenerAddr(l) {
	if (!l) return null;
	const host = l.host && l.host !== "0.0.0.0" && l.host !== "::" ? l.host : "127.0.0.1";
	return [host, parseInt(l.port, 10)];
}

// checkKafka — the client-facing listener accepts connections. This used to
// re-run the readiness command through probe.exec(), which has a hard 1 s
// timeout: kafka-broker-api-versions.sh starts a JVM and needs ~3 s, so the
// check reported false on a broker that was serving clients fine.
function checkKafka() {
	const a = listenerAddr(brokerListener());
	return a ? probe.tcp(a[0], a[1]) : false;
}

// checkProcess — probe.process() matches /proc/<pid>/comm, which is "java" for
// the broker JVM; "kafka.Kafka" is only the argument, so it never matched.
function checkProcess() {
	return probe.process("java");
}

// checkPort — the primary client-facing listener accepts TCP.
function checkPort() {
	const a = listenerAddr(controllerListener()) || listenerAddr(brokerListener());
	return a ? probe.tcp(a[0], a[1]) : false;
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
