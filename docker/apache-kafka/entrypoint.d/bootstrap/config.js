// config.js — declarative generation of server.properties, the log4j config
// and the legacy JAAS file.
//
// Precedence (highest last): generated defaults < user overrides
// (server.properties.user) < feature blocks (TLS/SASL/inter-broker) <
// KAFKA_CONFIG_* environment overrides.
const { env, fs, editor, log, config } = require("ezx");
const {
	KAFKA_SERVER_PROPERTIES,
	KAFKA_SERVER_PROPERTIES_ORIGINAL,
	KAFKA_SERVER_PROPERTIES_USER,
	KAFKA_CONFIG_MARKER,
	KAFKA_LOG4J_FILE,
	KAFKA_JAAS_FILE,
	KAFKA_LOG4J2,
	KAFKA_USER,
	KAFKA_GROUP,
	KAFKA_NODE_ID,
	KAFKA_PROCESS_ROLES,
	KAFKA_CONTROLLER_QUORUM_VOTERS,
	KAFKA_CONTROLLER_LISTENER_NAMES,
	KAFKA_LISTENERS,
	KAFKA_INTER_BROKER_LISTENER_NAME,
	KAFKA_ADVERTISED_LISTENERS,
	KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
	KAFKA_NUM_NETWORK_THREADS,
	KAFKA_NUM_IO_THREADS,
	KAFKA_SOCKET_SEND_BUFFER_BYTES,
	KAFKA_SOCKET_RECEIVE_BUFFER_BYTES,
	KAFKA_SOCKET_REQUEST_MAX_BYTES,
	KAFKA_NUM_PARTITIONS,
	KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR,
	KAFKA_LOG_DIRS,
	KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR,
	KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR,
	KAFKA_TRANSACTION_STATE_LOG_MIN_ISR,
	KAFKA_LOG_RETENTION_HOURS,
	KAFKA_LOG_SEGMENT_BYTES,
	KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS,
	KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS,
	KAFKA_MESSAGE_MAX_BYTES,
	KAFKA_REPLICA_FETCH_MAX_BYTES,
	KAFKA_MAX_CONNECTIONS_PER_IP,
	KAFKA_MAX_CONNECTION_CREATION_RATE,
	KAFKA_AUTO_CREATE_TOPICS_ENABLE,
	KAFKA_DELETE_TOPIC_ENABLE,
	KAFKA_SSL_ENABLE,
	KAFKA_SSL_KEYSTORE_TYPE,
	KAFKA_SSL_KEYSTORE_LOCATION,
	KAFKA_SSL_KEYSTORE_PASSWORD,
	KAFKA_SSL_KEY_PASSWORD,
	KAFKA_SSL_TRUSTSTORE_TYPE,
	KAFKA_SSL_TRUSTSTORE_LOCATION,
	KAFKA_SSL_TRUSTSTORE_PASSWORD,
	KAFKA_SSL_CLIENT_AUTH,
	KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM,
	KAFKA_SSL_PROTOCOL,
	KAFKA_SSL_ENABLED_PROTOCOLS,
	KAFKA_SSL_CIPHER_SUITES,
	KAFKA_SSL_KEYSTORE_KEY,
	KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN,
	KAFKA_SSL_TRUSTSTORE_CERTIFICATES,
	KAFKA_SASL_ENABLED_MECHANISMS,
	KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL,
	KAFKA_LOG4J_ROOT_LOGLEVEL,
	KAFKA_LOG4J_LOGGERS,
} = require("./env");
const {
	parseListeners,
	parseSecurityMap,
	listenerProtocol,
	protocolRequiresTls,
	protocolRequiresSasl,
	listenerConfigPrefix,
} = require("./util");
const { listenerJaasConfig } = require("./validation");

const OWNER = KAFKA_USER + ":" + KAFKA_GROUP;

// normalizeJaas — ensure a JAAS module string is terminated with a semicolon
// (the bash version also rewrote it; here we only guarantee termination).
function normalizeJaas(value) {
	const s = String(value || "").trim();
	if (s === "") return "";
	return s.endsWith(";") ? s : s + ";";
}

// userOverrides — key/value pairs from the user override file, in order.
function userOverrides() {
	if (!fs.exists(KAFKA_SERVER_PROPERTIES_USER)) return [];
	const pairs = [];
	for (const line of editor.open(KAFKA_SERVER_PROPERTIES_USER).read().split("\n")) {
		const trimmed = line.trim();
		if (trimmed === "" || trimmed.startsWith("#")) continue;
		const idx = trimmed.indexOf("=");
		if (idx <= 0) continue;
		pairs.push([trimmed.slice(0, idx).trim(), trimmed.slice(idx + 1)]);
	}
	return pairs;
}

// serverProperties — assemble the full server.properties content.
function serverProperties() {
	const b = config.builder({ separator: "=", valueFormat: "none" });

	// --- generated defaults ---
	const hasBroker = String(KAFKA_PROCESS_ROLES)
		.split(",")
		.map((r) => r.trim())
		.includes("broker");
	b.set("process.roles", KAFKA_PROCESS_ROLES);
	b.set("node.id", KAFKA_NODE_ID);
	b.set("controller.quorum.voters", KAFKA_CONTROLLER_QUORUM_VOTERS);
	b.set("controller.listener.names", KAFKA_CONTROLLER_LISTENER_NAMES);
	b.set("listeners", KAFKA_LISTENERS);
	// inter.broker.listener.name / advertised.listeners are broker-only.
	if (hasBroker) {
		b.set("inter.broker.listener.name", KAFKA_INTER_BROKER_LISTENER_NAME);
		b.set("advertised.listeners", KAFKA_ADVERTISED_LISTENERS);
	}
	b.set("listener.security.protocol.map", KAFKA_LISTENER_SECURITY_PROTOCOL_MAP);
	b.set("num.network.threads", KAFKA_NUM_NETWORK_THREADS);
	b.set("num.io.threads", KAFKA_NUM_IO_THREADS);
	b.set("socket.send.buffer.bytes", KAFKA_SOCKET_SEND_BUFFER_BYTES);
	b.set("socket.receive.buffer.bytes", KAFKA_SOCKET_RECEIVE_BUFFER_BYTES);
	b.set("socket.request.max.bytes", KAFKA_SOCKET_REQUEST_MAX_BYTES);
	b.set("num.partitions", KAFKA_NUM_PARTITIONS);
	b.set("num.recovery.threads.per.data.dir", KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR);
	b.set("log.dirs", KAFKA_LOG_DIRS);
	if (hasBroker) {
		b.set("offsets.topic.replication.factor", KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR);
		b.set("transaction.state.log.replication.factor", KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR);
		b.set("transaction.state.log.min.isr", KAFKA_TRANSACTION_STATE_LOG_MIN_ISR);
	}
	b.set("log.retention.hours", KAFKA_LOG_RETENTION_HOURS);
	b.set("log.segment.bytes", KAFKA_LOG_SEGMENT_BYTES);
	b.set("log.retention.check.interval.ms", KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS);
	b.set("group.initial.rebalance.delay.ms", KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS);
	b.set("message.max.bytes", KAFKA_MESSAGE_MAX_BYTES);
	b.set("replica.fetch.max.bytes", KAFKA_REPLICA_FETCH_MAX_BYTES);
	b.set("max.connections.per.ip", KAFKA_MAX_CONNECTIONS_PER_IP);
	b.set("max.connection.creation.rate", KAFKA_MAX_CONNECTION_CREATION_RATE);
	b.set("auto.create.topics.enable", KAFKA_AUTO_CREATE_TOPICS_ENABLE);
	b.set("delete.topic.enable", KAFKA_DELETE_TOPIC_ENABLE);

	// --- user overrides ---
	for (const [k, v] of userOverrides()) b.set(k, v);

	const securityMap = parseSecurityMap(KAFKA_LISTENER_SECURITY_PROTOCOL_MAP);
	const listeners = parseListeners(KAFKA_LISTENERS);
	const ibListener = listeners.find(
		(l) => l.name.toLowerCase() === String(KAFKA_INTER_BROKER_LISTENER_NAME).toLowerCase(),
	);
	const ibProto = ibListener ? listenerProtocol(ibListener, securityMap) : "";

	// --- TLS feature block ---
	if (KAFKA_SSL_ENABLE) {
		const pem = String(KAFKA_SSL_KEYSTORE_TYPE).toUpperCase() === "PEM";
		b.set("ssl.keystore.type", KAFKA_SSL_KEYSTORE_TYPE);
		if (pem) {
			b.set("ssl.keystore.key", KAFKA_SSL_KEYSTORE_KEY);
			b.set("ssl.keystore.certificate.chain", KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN);
		} else {
			b.set("ssl.keystore.location", KAFKA_SSL_KEYSTORE_LOCATION);
			b.set("ssl.keystore.password", KAFKA_SSL_KEYSTORE_PASSWORD);
			if (KAFKA_SSL_KEY_PASSWORD) b.set("ssl.key.password", KAFKA_SSL_KEY_PASSWORD);
		}
		if (pem) {
			b.set("ssl.truststore.type", "PEM");
			b.set("ssl.truststore.certificates", KAFKA_SSL_TRUSTSTORE_CERTIFICATES);
		} else if (KAFKA_SSL_TRUSTSTORE_LOCATION) {
			b.set("ssl.truststore.type", KAFKA_SSL_TRUSTSTORE_TYPE);
			b.set("ssl.truststore.location", KAFKA_SSL_TRUSTSTORE_LOCATION);
			b.set("ssl.truststore.password", KAFKA_SSL_TRUSTSTORE_PASSWORD);
		}
		b.set("ssl.client.auth", KAFKA_SSL_CLIENT_AUTH);
		b.set("ssl.endpoint.identification.algorithm", KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM);
		if (KAFKA_SSL_PROTOCOL) b.set("ssl.protocol", KAFKA_SSL_PROTOCOL);
		if (KAFKA_SSL_ENABLED_PROTOCOLS) b.set("ssl.enabled.protocols", KAFKA_SSL_ENABLED_PROTOCOLS);
		if (KAFKA_SSL_CIPHER_SUITES) b.set("ssl.cipher.suites", KAFKA_SSL_CIPHER_SUITES);
	}

	// --- SASL feature block ---
	const saslListeners = listeners.filter((l) =>
		protocolRequiresSasl(listenerProtocol(l, securityMap)),
	);
	if (saslListeners.length > 0) {
		const mechs = String(KAFKA_SASL_ENABLED_MECHANISMS)
			.split(",")
			.map((m) => m.trim().toUpperCase())
			.filter(Boolean);
		b.set("sasl.enabled.mechanisms", mechs.join(","));
		if (protocolRequiresSasl(ibProto)) {
			b.set("sasl.mechanism.inter.broker.protocol", KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL);
		}
		for (const l of saslListeners) {
			const jaas = normalizeJaas(listenerJaasConfig(l.name));
			if (jaas === "") continue; // SCRAM: credentials live in metadata
			for (const mech of mechs) {
				b.set(listenerConfigPrefix(l.name) + mech.toLowerCase() + ".sasl.jaas.config", jaas);
			}
		}
	}

	// --- KAFKA_CONFIG_* overrides (last: env wins over everything) ---
	for (const [k, v] of Object.entries(env.all()).sort(([a], [b]) => a.localeCompare(b))) {
		if (!/^KAFKA_CONFIG_/.test(k)) continue;
		if (v === "") continue;
		b.set(k.replace(/^KAFKA_CONFIG_/, "").toLowerCase().replace(/_/g, "."), String(v));
	}

	return b.build();
}

// log4jProperties — a stdout-only logging config, so ezx owns rotation and
// every broker's logs land in one captured stream. Kafka 3.9 uses log4j 1.x
// (properties, -Dlog4j.configuration); 4.x uses log4j2 (properties format,
// -Dlog4j2.configurationFile).
function log4jProperties() {
	if (!KAFKA_LOG4J2) {
		const b = config.builder({ separator: "=", valueFormat: "none" });
		b.set("log4j.rootLogger", KAFKA_LOG4J_ROOT_LOGLEVEL + ", stdout");
		b.set("log4j.appender.stdout", "org.apache.log4j.ConsoleAppender");
		b.set("log4j.appender.stdout.target", "System.out");
		b.set("log4j.appender.stdout.layout", "org.apache.log4j.PatternLayout");
		b.set("log4j.appender.stdout.layout.ConversionPattern", "[%d] %p %m (%c)%n");
		for (const l of parseLoggers(KAFKA_LOG4J_LOGGERS)) b.set("log4j.logger." + l.name, l.level);
		return b.build();
	}
	const b = config.builder({ separator: " = ", valueFormat: "none" });
	b.set("status", "error");
	b.set("name", "KafkaLog4j2Config");
	b.set("appender.console.type", "Console");
	b.set("appender.console.name", "STDOUT");
	b.set("appender.console.target", "SYSTEM_OUT");
	b.set("appender.console.layout.type", "PatternLayout");
	b.set("appender.console.layout.pattern", "[%d] %p %m (%c)%n");
	b.set("rootLogger.level", KAFKA_LOG4J_ROOT_LOGLEVEL);
	b.set("rootLogger.appenderRef.stdout.ref", "STDOUT");
	parseLoggers(KAFKA_LOG4J_LOGGERS).forEach((l, i) => {
		b.set("logger." + i + ".name", l.name);
		b.set("logger." + i + ".level", l.level);
	});
	return b.build();
}

// parseLoggers — "kafka.controller:TRACE,kafka.log.LogCleaner:INFO" -> [{name,level}].
function parseLoggers(spec) {
	const out = [];
	for (const entry of String(spec || "").split(",")) {
		const part = entry.trim();
		if (part === "") continue;
		const idx = part.lastIndexOf(":");
		if (idx <= 0) continue;
		out.push({ name: part.slice(0, idx).trim(), level: part.slice(idx + 1).trim().toUpperCase() });
	}
	return out;
}

// jaasFile — legacy JAAS login file for tools that still read
// -Djava.security.auth.login.config. The broker itself uses the inline
// listener.name.*.sasl.jaas.config keys.
function jaasFile() {
	const cfg = String(env.get("KAFKA_SASL_JAAS_CONFIG", "")).trim();
	if (cfg === "") return null;
	const normalized = normalizeJaas(cfg);
	return (
		"KafkaServer {\n    " + normalized + "\n};\n" +
		"KafkaClient {\n    " + normalized + "\n};\n"
	);
}

// prepareUserConfig — first boot only: if a server.properties exists and was not
// written by us, preserve it as .original and seed .user so its keys keep
// winning over generated defaults on later boots.
function prepareUserConfig() {
	if (!fs.exists(KAFKA_SERVER_PROPERTIES) || fs.exists(KAFKA_CONFIG_MARKER)) return;
	try {
		fs.copy(KAFKA_SERVER_PROPERTIES, KAFKA_SERVER_PROPERTIES_ORIGINAL, { overwrite: false });
		if (!fs.exists(KAFKA_SERVER_PROPERTIES_USER)) {
			fs.copy(KAFKA_SERVER_PROPERTIES, KAFKA_SERVER_PROPERTIES_USER, { overwrite: false });
		}
		log.info(
			"Preserved user-provided server.properties as server.properties.original / server.properties.user",
		);
	} catch (e) {
		log.warn("Could not preserve pre-existing server.properties: " + e.message);
	}
}

// writeFile — write a generated config file as kafka:kafka with strict modes.
function writeFile(path, content, mode) {
	try {
		fs.write(path, content, { mode: mode });
		fs.chown(path, OWNER);
		fs.chmod(path, mode);
	} catch (e) {
		throw new Error(
			"cannot write " + path + " (" + e.message + "); mount the config path read-write or use server.properties.user for overrides",
		);
	}
}

// provisionConfig — write server.properties + log4j + JAAS. Called from main.js
// before storage formatting (which needs server.properties) and again by the
// declarative node files so env changes are picked up.
function provisionConfig() {
	writeFile(KAFKA_SERVER_PROPERTIES, serverProperties(), 0o600);
	writeFile(KAFKA_LOG4J_FILE, log4jProperties(), 0o644);
	const jaas = jaasFile();
	if (jaas !== null) writeFile(KAFKA_JAAS_FILE, jaas, 0o600);
	fs.write(KAFKA_CONFIG_MARKER, "generated\n", { mode: 0o644 });
	log.info("Generated " + KAFKA_SERVER_PROPERTIES + " and logging config");
}

module.exports = {
	serverProperties,
	log4jProperties,
	jaasFile,
	provisionConfig,
	prepareUserConfig,
	normalizeJaas,
	parseLoggers,
};
