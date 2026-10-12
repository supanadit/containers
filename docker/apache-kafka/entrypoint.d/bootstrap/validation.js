// validation.js — validate the container environment and required dependencies
// before any side effects. Ported from the bash utils/validation.sh and
// extended with the cross-field checks the bash version lacked (listener /
// security-map consistency, TLS/SASL prerequisites, replication factors).
const { env, log, scheduler, fs } = require("ezx");
const {
	KAFKA_PROCESS_ROLES,
	KAFKA_LISTENERS,
	KAFKA_ADVERTISED_LISTENERS,
	KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
	KAFKA_CONTROLLER_LISTENER_NAMES,
	KAFKA_INTER_BROKER_LISTENER_NAME,
	KAFKA_CONTROLLER_QUORUM_VOTERS,
	KAFKA_SASL_ENABLED_MECHANISMS,
	KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL,
	KAFKA_SASL_JAAS_CONFIG,
	KAFKA_SASL_SCRAM_USERS,
	KAFKA_SSL_ENABLE,
	KAFKA_SSL_KEYSTORE_TYPE,
	KAFKA_SSL_KEYSTORE_LOCATION,
	KAFKA_SSL_KEYSTORE_KEY,
	KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN,
	KAFKA_SSL_TRUSTSTORE_LOCATION,
	KAFKA_SSL_TRUSTSTORE_CERTIFICATES,
	KAFKA_SSL_CLIENT_AUTH,
	KAFKA_CLUSTER_ID,
	KAFKA_METADATA_BACKUP_ENABLE,
	KAFKA_METADATA_BACKUP_SCHEDULE,
	KAFKA_METADATA_BACKUP_RETENTION_DAYS,
	KAFKA_HEAP_OPTS,
	KAFKA_READY_MAX_ATTEMPTS,
	KAFKA_READY_ATTEMPT_INTERVAL,
} = require("./env");
const {
	parseListeners,
	parseSecurityMap,
	listenerProtocol,
	protocolRequiresTls,
	protocolRequiresSasl,
	isPositiveInt,
	isNonNegativeInt,
	isSize,
} = require("./util");

const VALID_PROTOCOLS = ["PLAINTEXT", "SSL", "SASL_PLAINTEXT", "SASL_SSL"];
const VALID_MECHANISMS = ["PLAIN", "SCRAM-SHA-256", "SCRAM-SHA-512"];
const VALID_SSL_CLIENT_AUTH = ["none", "requested", "required"];

// validateCronExpression — delegate to ezx's cron engine so validation always
// matches what the scheduler actually runs.
function validateCronExpression(expr) {
	try {
		scheduler.parse(expr);
		return true;
	} catch {
		return false;
	}
}

// parseScramUsers — parse "user:pass[,user:pass]" into [{user, pass}] or null
// on a malformed entry.
function parseScramUsers(spec) {
	if (!spec) return [];
	const out = [];
	for (const entry of String(spec).split(",")) {
		const part = entry.trim();
		if (part === "") continue;
		const idx = part.indexOf(":");
		if (idx <= 0 || idx === part.length - 1) return null;
		out.push({ user: part.slice(0, idx), pass: part.slice(idx + 1) });
	}
	return out;
}

// listenerJaasConfig — the JAAS module string for a listener, from the global
// KAFKA_SASL_JAAS_CONFIG or the per-listener KAFKA_SASL_JAAS_CONFIG_<NAME>.
function listenerJaasConfig(name) {
	const specific = env.get("KAFKA_SASL_JAAS_CONFIG_" + String(name).toUpperCase(), "");
	return specific || KAFKA_SASL_JAAS_CONFIG;
}

function validateEnvironment() {
	let failed = false;
	const fail = (msg) => {
		log.error(msg);
		failed = true;
	};
	const warn = (msg) => log.warn(msg);

	// LOG_LEVEL
	const logLevel = String(env.get("LOG_LEVEL", "INFO")).toUpperCase();
	if (!["DEBUG", "INFO", "WARN", "ERROR"].includes(logLevel)) {
		fail(`Invalid LOG_LEVEL: ${env.get("LOG_LEVEL")} (must be DEBUG, INFO, WARN, or ERROR)`);
	}

	// SLEEP_MODE / KAFKA_SLEEP_MODE
	for (const name of ["SLEEP_MODE", "KAFKA_SLEEP_MODE"]) {
		const v = env.get(name, "false");
		if (v !== "" && !["true", "false", "1", "0", "yes", "no", "on", "off"].includes(v.toLowerCase())) {
			fail(`Invalid ${name}: ${v} (must be true or false)`);
		}
	}

	// KAFKA_NODE_ID
	if (!isNonNegativeInt(env.get("KAFKA_NODE_ID", "1"))) {
		fail(`Invalid KAFKA_NODE_ID: ${env.get("KAFKA_NODE_ID")} (must be a non-negative integer)`);
	}

	// KAFKA_PROCESS_ROLES
	const roles = String(KAFKA_PROCESS_ROLES)
		.split(",")
		.map((r) => r.trim())
		.filter(Boolean);
	if (roles.length === 0) {
		fail("KAFKA_PROCESS_ROLES is empty (must be broker and/or controller)");
	}
	for (const role of roles) {
		if (!["broker", "controller"].includes(role)) {
			fail(`Invalid role in KAFKA_PROCESS_ROLES: ${role} (must be broker and/or controller)`);
		}
	}
	const hasBroker = roles.includes("broker");
	const hasController = roles.includes("controller");

	// Positive integer / size knobs
	for (const v of [
		"KAFKA_NUM_NETWORK_THREADS",
		"KAFKA_NUM_IO_THREADS",
		"KAFKA_NUM_PARTITIONS",
		"KAFKA_READY_MAX_ATTEMPTS",
		"KAFKA_READY_ATTEMPT_INTERVAL",
		"KAFKA_SOCKET_SEND_BUFFER_BYTES",
		"KAFKA_SOCKET_RECEIVE_BUFFER_BYTES",
		"KAFKA_SOCKET_REQUEST_MAX_BYTES",
		"KAFKA_LOG_SEGMENT_BYTES",
		"KAFKA_MESSAGE_MAX_BYTES",
		"KAFKA_REPLICA_FETCH_MAX_BYTES",
	]) {
		const val = env.get(v);
		if (val !== undefined && !isSize(val)) {
			fail(`Invalid ${v}: ${val} (must be a non-negative integer byte count)`);
		}
	}
	if (!isNonNegativeInt(env.get("KAFKA_LOG_RETENTION_HOURS", "168"))) {
		fail(
			`Invalid KAFKA_LOG_RETENTION_HOURS: ${env.get("KAFKA_LOG_RETENTION_HOURS")} (must be a non-negative integer)`,
		);
	}

	// Listener / security-map consistency
	const listeners = parseListeners(KAFKA_LISTENERS);
	const securityMap = parseSecurityMap(KAFKA_LISTENER_SECURITY_PROTOCOL_MAP);
	if (listeners.length === 0) {
		fail("KAFKA_LISTENERS is empty");
	}
	for (const l of listeners) {
		if (!l.valid) {
			fail(`Invalid listener entry: ${l.url} (expected NAME://host:port)`);
			continue;
		}
		const proto = listenerProtocol(l, securityMap);
		if (!proto) {
			fail(
				`Listener ${l.name} has no entry in KAFKA_LISTENER_SECURITY_PROTOCOL_MAP`,
			);
			continue;
		}
		if (!VALID_PROTOCOLS.includes(proto)) {
			fail(`Invalid security protocol for listener ${l.name}: ${proto}`);
		}
	}

	// controller.listener.names must reference declared listeners.
	for (const ctl of String(KAFKA_CONTROLLER_LISTENER_NAMES)
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean)) {
		if (!listeners.some((l) => l.name.toLowerCase() === ctl.toLowerCase())) {
			fail(`KAFKA_CONTROLLER_LISTENER_NAMES references unknown listener: ${ctl}`);
		}
	}

	// inter.broker.listener.name / advertised.listeners are broker-only
	// concerns; controller-only nodes legitimately omit them.
	const ibListener = listeners.find(
		(l) => l.name.toLowerCase() === String(KAFKA_INTER_BROKER_LISTENER_NAME).toLowerCase(),
	);
	const ibProto = ibListener ? listenerProtocol(ibListener, securityMap) : "";
	if (hasBroker) {
		if (!ibListener) {
			fail(`KAFKA_INTER_BROKER_LISTENER_NAME references unknown listener: ${KAFKA_INTER_BROKER_LISTENER_NAME}`);
		}
		for (const a of parseListeners(KAFKA_ADVERTISED_LISTENERS)) {
			if (!a.valid || a.host === "") {
				fail(`Invalid KAFKA_ADVERTISED_LISTENERS entry: ${a.url} (expected NAME://host:port)`);
				continue;
			}
			if (!listeners.some((l) => l.name.toLowerCase() === a.name.toLowerCase())) {
				fail(`Advertised listener ${a.name} has no matching entry in KAFKA_LISTENERS`);
			}
		}
	}

	// TLS prerequisites
	const tlsListener = listeners.find((l) => protocolRequiresTls(listenerProtocol(l, securityMap)));
	if (tlsListener && !KAFKA_SSL_ENABLE) {
		fail(
			`Listener ${tlsListener.name} requires TLS but KAFKA_SSL_ENABLE is false; set KAFKA_SSL_ENABLE=true`,
		);
	}
	if (KAFKA_SSL_ENABLE) {
		const pem = String(KAFKA_SSL_KEYSTORE_TYPE).toUpperCase() === "PEM";
		if (pem) {
			if (!KAFKA_SSL_KEYSTORE_KEY || !KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN) {
				fail("KAFKA_SSL_ENABLE=true with PEM keystore requires KAFKA_SSL_KEYSTORE_KEY and KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN");
			}
		} else if (!KAFKA_SSL_KEYSTORE_LOCATION) {
			fail("KAFKA_SSL_ENABLE=true requires KAFKA_SSL_KEYSTORE_LOCATION (or PEM key/chain)");
		}
		const hasTrust = pem ? !!KAFKA_SSL_TRUSTSTORE_CERTIFICATES : !!KAFKA_SSL_TRUSTSTORE_LOCATION;
		if (!hasTrust && ["requested", "required"].includes(String(KAFKA_SSL_CLIENT_AUTH).toLowerCase())) {
			fail(`KAFKA_SSL_CLIENT_AUTH=${KAFKA_SSL_CLIENT_AUTH} requires a truststore`);
		}
		if (!VALID_SSL_CLIENT_AUTH.includes(String(KAFKA_SSL_CLIENT_AUTH).toLowerCase())) {
			fail(`Invalid KAFKA_SSL_CLIENT_AUTH: ${KAFKA_SSL_CLIENT_AUTH} (must be none, requested, or required)`);
		}
	}

	// SASL prerequisites
	const saslListeners = listeners.filter((l) =>
		protocolRequiresSasl(listenerProtocol(l, securityMap)),
	);
	if (saslListeners.length > 0) {
		const mechs = String(KAFKA_SASL_ENABLED_MECHANISMS)
			.split(",")
			.map((m) => m.trim())
			.filter(Boolean);
		if (mechs.length === 0) {
			fail("A SASL listener is configured but KAFKA_SASL_ENABLED_MECHANISMS is empty");
		}
		for (const m of mechs) {
			if (!VALID_MECHANISMS.includes(m.toUpperCase())) {
				fail(`Invalid SASL mechanism: ${m} (must be PLAIN, SCRAM-SHA-256, or SCRAM-SHA-512)`);
			}
		}
		for (const l of saslListeners) {
			const jaas = listenerJaasConfig(l.name);
			const plainOnly = mechs.every((m) => m.toUpperCase() === "PLAIN");
			if (!jaas && plainOnly) {
				fail(
					`SASL listener ${l.name} uses PLAIN but no JAAS config is set (KAFKA_SASL_JAAS_CONFIG or KAFKA_SASL_JAAS_CONFIG_${l.name.toUpperCase()})`,
				);
			} else if (!jaas) {
				warn(
					`SASL listener ${l.name} has no JAAS config; SCRAM credentials are expected to exist in metadata`,
				);
			}
		}
		if (protocolRequiresSasl(ibProto)) {
			const ibMech = String(KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL || "").toUpperCase();
			if (!mechs.map((m) => m.toUpperCase()).includes(ibMech)) {
				fail(
					`KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL=${KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL} is not in KAFKA_SASL_ENABLED_MECHANISMS`,
				);
			}
		}
	} else if (KAFKA_SASL_JAAS_CONFIG || KAFKA_SASL_SCRAM_USERS) {
		warn("SASL config is set but no SASL listener is configured; it will be ignored");
	}

	if (KAFKA_SASL_SCRAM_USERS && parseScramUsers(KAFKA_SASL_SCRAM_USERS) === null) {
		fail("Invalid KAFKA_SASL_SCRAM_USERS (expected user:pass[,user:pass...])");
	}

	// KRaft quorum voters + replication factor sanity.
	const voters = String(KAFKA_CONTROLLER_QUORUM_VOTERS)
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean);
	const seenIds = {};
	for (const v of voters) {
		const m = /^([0-9]+)@[^:]+:([0-9]+)$/.exec(v);
		if (!m) {
			fail(`Invalid KAFKA_CONTROLLER_QUORUM_VOTERS entry: ${v} (expected id@host:port)`);
			continue;
		}
		if (seenIds[m[1]]) fail(`Duplicate controller id in KAFKA_CONTROLLER_QUORUM_VOTERS: ${m[1]}`);
		seenIds[m[1]] = true;
	}
	if (hasBroker && hasController && voters.length > 0) {
		for (const v of [
			"KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR",
			"KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR",
		]) {
			const f = parseInt(env.get(v, "1"), 10);
			if (f > voters.length) {
				fail(`${v}=${f} exceeds the ${voters.length} known broker/controller node(s); it must be <= the number of brokers`);
			}
		}
		const isr = parseInt(env.get("KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", "1"), 10);
		const trf = parseInt(env.get("KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", "1"), 10);
		if (isr > trf) {
			fail(`KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=${isr} cannot exceed KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=${trf}`);
		}
	}

	// KAFKA_CLUSTER_ID must be non-empty when set (empty means "auto").
	if (env.has("KAFKA_CLUSTER_ID") && !KAFKA_CLUSTER_ID) {
		warn("KAFKA_CLUSTER_ID is set but empty; the cluster id will be generated");
	}

	// JVM heap sanity.
	if (KAFKA_HEAP_OPTS && !String(KAFKA_HEAP_OPTS).includes("-X")) {
		warn(`KAFKA_HEAP_OPTS does not look like JVM flags: ${KAFKA_HEAP_OPTS}`);
	}

	// Metadata backup schedule.
	if (KAFKA_METADATA_BACKUP_ENABLE) {
		if (!validateCronExpression(KAFKA_METADATA_BACKUP_SCHEDULE)) {
			fail(`Invalid KAFKA_METADATA_BACKUP_SCHEDULE: ${KAFKA_METADATA_BACKUP_SCHEDULE} (must be a 5-field cron expression)`);
		}
		if (!isPositiveInt(KAFKA_METADATA_BACKUP_RETENTION_DAYS)) {
			fail(`Invalid KAFKA_METADATA_BACKUP_RETENTION_DAYS: ${KAFKA_METADATA_BACKUP_RETENTION_DAYS} (must be a positive integer)`);
		}
	}

	// KAFKA_CONFIG_* reserved-key guard: these are container-managed and must
	// not be silently overridden (would break the bootstrap invariants).
	for (const key of Object.keys(env.all())) {
		if (!/^KAFKA_CONFIG_/.test(key)) continue;
		const prop = key.replace(/^KAFKA_CONFIG_/, "").toLowerCase().replace(/_/g, ".");
		if (["process.roles", "node.id", "controller.quorum.voters", "listeners"].includes(prop)) {
			fail(`KAFKA_CONFIG_* cannot override the container-managed key '${prop}'; use the dedicated env var instead`);
		}
	}

	return !failed;
}

// validateDependencies — required binaries exist before starting.
function validateDependencies() {
	let failed = false;
	const fail = (msg) => {
		log.error(msg);
		failed = true;
	};

	const roles = String(KAFKA_PROCESS_ROLES).split(",").map((r) => r.trim());
	const required = ["java", "kafka-server-start.sh", "kafka-storage.sh"];
	if (roles.includes("broker")) required.push("kafka-broker-api-versions.sh");
	if (roles.includes("controller")) required.push("kafka-metadata-quorum.sh");
	if (KAFKA_METADATA_BACKUP_ENABLE) required.push("kafka-metadata.sh");

	for (const cmd of required) {
		if (!fs.which(cmd)) fail(`Required command not found: ${cmd}`);
	}

	return !failed;
}

module.exports = {
	validateEnvironment,
	validateDependencies,
	validateCronExpression,
	parseScramUsers,
	listenerJaasConfig,
};
