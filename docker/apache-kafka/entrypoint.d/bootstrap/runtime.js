// runtime.js — supervise the Kafka broker/controller process and its optional
// sidecars in a single flat DAG. ezx stays PID 1 and never exec's away.
//
// Nodes:
//   kafka                — the broker/controller root (long-running)
//   kafka-scram-init     — oneshot: register configured SCRAM users (optional)
//   kafka-config-backup  — scheduled: export topic/config metadata (optional)
//
// Config generation and storage formatting happen in main.js before the chain
// starts (format needs the generated server.properties), so the kafka node
// depends on nothing.
const { env, fs, editor, process, chain, scheduler, log } = require("ezx");
const {
	KAFKA_USER,
	KAFKA_GROUP,
	KAFKA_LOG_DIR,
	KAFKA_RUN_DIR,
	KAFKA_BACKUP_DIR,
	KAFKA_SERVER_PROPERTIES,
	KAFKA_LOG4J_FILE,
	KAFKA_LOG4J2,
	KAFKA_PROCESS_ROLES,
	KAFKA_LISTENERS,
	KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
	KAFKA_CONTROLLER_LISTENER_NAMES,
	KAFKA_SASL_ENABLED_MECHANISMS,
	KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL,
	KAFKA_SASL_JAAS_CONFIG,
	KAFKA_SSL_ENABLE,
	KAFKA_SSL_TRUSTSTORE_LOCATION,
	KAFKA_SSL_KEYSTORE_LOCATION,
	KAFKA_HEAP_OPTS,
	KAFKA_JVM_PERFORMANCE_OPTS,
	KAFKA_METADATA_BACKUP_ENABLE,
	KAFKA_METADATA_BACKUP_SCHEDULE,
	KAFKA_METADATA_BACKUP_TIMEZONE,
	KAFKA_METADATA_BACKUP_RETENTION_DAYS,
	KAFKA_READY_MAX_ATTEMPTS,
	KAFKA_READY_ATTEMPT_INTERVAL,
} = require("./env");
const {
	parseListeners,
	parseSecurityMap,
	listenerProtocol,
	protocolRequiresTls,
	protocolRequiresSasl,
	saslMechanismClass,
} = require("./util");
const { listenerJaasConfig } = require("./validation");
const { bootstrapScram, firstBrokerBootstrap } = require("./kraft");
const { normalizeJaas } = require("./config");

const OWNER = KAFKA_USER + ":" + KAFKA_GROUP;

// logFor — a per-node rotated log file under /opt/containers/logs.
function logFor(name, maxBytes, maxBackups) {
	return {
		stdout: "file",
		stderr: "file",
		filePath: KAFKA_LOG_DIR + "/" + name + ".log",
		maxBytes: maxBytes,
		maxBackups: maxBackups,
	};
}

// listenersByRole — declared listeners plus their resolved security protocol.
function listenersByRole() {
	const securityMap = parseSecurityMap(KAFKA_LISTENER_SECURITY_PROTOCOL_MAP);
	return parseListeners(KAFKA_LISTENERS)
		.filter((l) => l.valid && l.port)
		.map((l) => ({ ...l, protocol: listenerProtocol(l, securityMap) }));
}

// controllerNames — the declared controller-listener names (lowercased).
function controllerNames() {
	return String(KAFKA_CONTROLLER_LISTENER_NAMES)
		.split(",")
		.map((s) => s.trim().toLowerCase())
		.filter(Boolean);
}

// brokerListener / controllerListener — first matching listener with a port.
// Classification is by listener name (the CONTROLLER listener maps to a
// non-CONTROLLER security protocol, so the protocol alone cannot decide).
function brokerListener() {
	const ctl = controllerNames();
	return listenersByRole().find((l) => !ctl.includes(l.name.toLowerCase())) || null;
}

function controllerListener() {
	const ctl = controllerNames();
	return listenersByRole().find((l) => ctl.includes(l.name.toLowerCase())) || null;
}

function connectHost(l) {
	return l.host && l.host !== "0.0.0.0" && l.host !== "::" ? l.host : "127.0.0.1";
}

// securityClientArgs — client security flags for the given listener. Writes a
// shared client.properties when TLS/SASL is in play and returns
// ["--command-config", path]; otherwise [].
function securityClientArgs(target) {
	if (!target) return [];
	const needsSasl = protocolRequiresSasl(target.protocol);
	const needsTls = protocolRequiresTls(target.protocol);
	if (!needsSasl && !needsTls) return [];

	const lines = ["security.protocol=" + target.protocol];
	if (needsSasl) {
		const mech = String(
			KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL ||
				String(KAFKA_SASL_ENABLED_MECHANISMS).split(",")[0] ||
				"PLAIN",
		)
			.trim()
			.toUpperCase();
		lines.push("sasl.mechanism=" + mech);
		const jaas = normalizeJaas(listenerJaasConfig(target.name) || KAFKA_SASL_JAAS_CONFIG);
		if (jaas) lines.push("sasl.jaas.config=" + jaas);
	}
	if (needsTls && KAFKA_SSL_ENABLE) {
		if (KAFKA_SSL_TRUSTSTORE_LOCATION) lines.push("ssl.truststore.location=" + KAFKA_SSL_TRUSTSTORE_LOCATION);
		if (KAFKA_SSL_KEYSTORE_LOCATION) lines.push("ssl.keystore.location=" + KAFKA_SSL_KEYSTORE_LOCATION);
		lines.push("ssl.endpoint.identification.algorithm=");
	}
	const file = KAFKA_RUN_DIR + "/client.properties";
	const content = lines.join("\n") + "\n";
	// Write only when missing/stale: health checks call this from HTTP
	// goroutines and must not rewrite the file on every probe.
	const current = fs.exists(file) ? editor.open(file).read() : "";
	if (current !== content) {
		fs.write(file, content, { mode: 0o600 });
		fs.chown(file, OWNER);
		fs.chmod(file, 0o600);
	}
	return ["--command-config", file];
}

// readyProbe — broker API readiness for broker/combined nodes; KRaft metadata
// quorum status for controller-only nodes.
function readyProbe() {
	const roles = String(KAFKA_PROCESS_ROLES).split(",").map((r) => r.trim());
	if (roles.includes("broker")) {
		const l = brokerListener();
		if (!l) return { type: "exec", exec: ["kafka-broker-api-versions.sh", "--bootstrap-server", "127.0.0.1:9092"] };
		return {
			type: "exec",
			exec: ["kafka-broker-api-versions.sh", "--bootstrap-server", connectHost(l) + ":" + l.port].concat(
				securityClientArgs(l),
			),
		};
	}
	const l = controllerListener();
	if (!l) return { type: "exec", exec: ["kafka-metadata-quorum.sh", "--bootstrap-server", "127.0.0.1:9093", "describe", "--status"] };
	return {
		type: "exec",
		exec: [
			"kafka-metadata-quorum.sh",
			"--bootstrap-server",
			connectHost(l) + ":" + l.port,
			"describe",
			"--status",
		].concat(securityClientArgs(l)),
	};
}

// kafkaEnv — JVM/logging environment for the broker process.
function kafkaEnv() {
	const list = [];
	if (KAFKA_HEAP_OPTS) list.push("KAFKA_HEAP_OPTS=" + KAFKA_HEAP_OPTS);
	if (KAFKA_JVM_PERFORMANCE_OPTS) list.push("KAFKA_JVM_PERFORMANCE_OPTS=" + KAFKA_JVM_PERFORMANCE_OPTS);
	// Pin the log4j config; kafka-run-class.sh only sets a default when empty.
	const prop = KAFKA_LOG4J2 ? "-Dlog4j2.configurationFile=file:" : "-Dlog4j.configuration=file:";
	list.push("KAFKA_LOG4J_OPTS=" + prop + KAFKA_LOG4J_FILE);
	return list;
}

function kafkaNode() {
	return {
		name: "kafka",
		process: {
			binaryPath: "kafka-server-start.sh",
			arguments: [KAFKA_SERVER_PROPERTIES],
			user: KAFKA_USER,
			group: KAFKA_GROUP,
			environment: kafkaEnv(),
			log: logFor("kafka", 50 * 1024 * 1024, 5),
		},
		readiness: {
			...readyProbe(),
			interval: KAFKA_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: KAFKA_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

// scramInitNode — register SCRAM users once the broker is ready. Optional: a
// failure never takes the broker down.
function scramInitNode() {
	if (!KAFKA_SASL_JAAS_CONFIG && !env.get("KAFKA_SASL_SCRAM_USERS", "")) return null;
	if (!env.get("KAFKA_SASL_SCRAM_USERS", "")) return null;
	return {
		name: "kafka-scram-init",
		oneshot: true,
		optional: true,
		// "started" (not "ready"): on a fresh SCRAM cluster the readiness probe
		// itself needs credentials, so waiting for ready would deadlock. A short
		// settle delay lets the broker open its listener, then we add the users.
		dependsOnEdges: [{ name: "kafka", waitFor: "started" }],
		// Callback-only oneshot: `onStart` runs to completion before dependents
		// proceed, so the settle sleep + SCRAM bootstrap stay ordered correctly.
		onStart: () => {
			process.sleep(5e9);
			bootstrapScram();
		},
		log: logFor("kafka-scram-init", 10 * 1024 * 1024, 3),
	};
}

// timestamp — YYYYMMDD_HHMMSS.
function pad(n) {
	return String(n).padStart(2, "0");
}

function timestamp(now) {
	return (
		now.getFullYear() +
		pad(now.getMonth() + 1) +
		pad(now.getDate()) +
		"_" +
		pad(now.getHours()) +
		pad(now.getMinutes()) +
		pad(now.getSeconds())
	);
}

// runConfigBackup — export topic and dynamic-config metadata to a timestamped
// directory, then expire old snapshots. Kafka's cluster metadata log cannot be
// safely copied while the broker is running; the portable, online-safe backup is
// the declarative cluster configuration.
function runConfigBackup() {
	const target = firstBrokerBootstrap();
	if (!target) {
		log.warn("No broker listener available; skipping config backup");
		return;
	}
	const now = new Date();
	const dir = KAFKA_BACKUP_DIR + "/config_" + timestamp(now);
	fs.ensureDir(dir, { mode: 0o750, owner: OWNER });
	const cfg = securityClientArgs(target);
	const boot = target.host + ":" + target.port;
	const tools = [
		{ name: "topics", argv: ["kafka-topics.sh", "--bootstrap-server", boot, "--describe"] },
		{ name: "topic-configs", argv: ["kafka-configs.sh", "--bootstrap-server", boot, "--describe", "--entity-type", "topics"] },
		{ name: "broker-configs", argv: ["kafka-configs.sh", "--bootstrap-server", boot, "--describe", "--entity-type", "brokers"] },
		{ name: "storage-info", argv: ["kafka-storage.sh", "info", "-c", KAFKA_SERVER_PROPERTIES] },
	];
	for (const t of tools) {
		const res = process.capture({
			name: "kafka-backup-" + t.name,
			process: {
				binaryPath: t.argv[0],
				arguments: t.argv.slice(1).concat(cfg),
				user: KAFKA_USER,
				group: KAFKA_GROUP,
			},
		});
		const body = String(res.stdout || "") + (res.stderr ? "\n# stderr:\n" + res.stderr : "");
		fs.write(dir + "/" + t.name + ".txt", body, { mode: 0o600, owner: OWNER });
	}
	expireBackups(now);
	log.info("Config backup written to " + dir);
}

// expireBackups — remove config_* snapshots older than the retention window
// (always keeping the newest).
function expireBackups(now) {
	if (!fs.exists(KAFKA_BACKUP_DIR)) return;
	const days = parseInt(KAFKA_METADATA_BACKUP_RETENTION_DAYS, 10);
	const cutoff = now.getTime() - days * 86400000;
	const snaps = fs
		.readDir(KAFKA_BACKUP_DIR)
		.filter((n) => /^config_\d{8}_\d{6}$/.test(n))
		.sort();
	for (let i = 0; i < snaps.length - 1; i++) {
		const m = /^config_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$/.exec(snaps[i]);
		if (!m) continue;
		const when = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime();
		if (when < cutoff) {
			fs.removeAll(KAFKA_BACKUP_DIR + "/" + snaps[i]);
			log.info("Removed expired config backup: " + snaps[i]);
		}
	}
}

// backupNode — scheduled config-backup callback (ezx scheduler.every).
function backupNode() {
	if (!KAFKA_METADATA_BACKUP_ENABLE) return null;
	return {
		name: "kafka-config-backup",
		optional: true,
		dependsOnEdges: [{ name: "kafka", waitFor: "ready" }],
		scheduler: scheduler.every(KAFKA_METADATA_BACKUP_SCHEDULE, () => runConfigBackup(), {
			timezone: KAFKA_METADATA_BACKUP_TIMEZONE,
			initialDelay: 60e9,
		}),
	};
}

// buildNodes — flat DAG: kafka root + optional sidecars.
function buildNodes() {
	const nodes = [kafkaNode()];
	for (const n of [scramInitNode(), backupNode()]) {
		if (n) nodes.push(n);
	}
	return nodes;
}

function startDatabase() {
	chain.run({ nodes: buildNodes() });
}

// startSleep — hold the container open without starting Kafka.
function startSleep() {
	chain.run({
		nodes: [
			{
				name: "sleep",
				process: {},
				restart: { mode: "always", backoff: 1000 * 1e6 },
			},
		],
	});
}

module.exports = {
	startDatabase,
	startSleep,
	buildNodes,
	kafkaNode,
	scramInitNode,
	backupNode,
	readyProbe,
	securityClientArgs,
	runConfigBackup,
	brokerListener,
	controllerListener,
	logFor,
};
