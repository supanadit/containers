// kraft.js — KRaft cluster-id resolution and idempotent storage formatting.
//
// Replaces the bash startup.sh manage_cluster_id/format_storage helpers. The
// old format step piped `kafka-storage.sh format` through `grep -q "already
// formatted"`, which reported success even on unrelated failures; here the exit
// code is the single source of truth and any failure throws.
const { fs, process, editor, log } = require("ezx");
const {
	KAFKA_DATA_DIR,
	KAFKA_CLUSTER_ID,
	KAFKA_CLUSTER_ID_FILE,
	KAFKA_META_PROPERTIES,
	KAFKA_SERVER_PROPERTIES,
	KAFKA_USER,
	KAFKA_GROUP,
	KAFKA_LISTENERS,
	KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
	KAFKA_CONTROLLER_LISTENER_NAMES,
	KAFKA_SASL_JAAS_CONFIG,
	KAFKA_SASL_ENABLED_MECHANISMS,
	KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL,
	KAFKA_SASL_SCRAM_USERS,
	KAFKA_SSL_ENABLE,
	KAFKA_SSL_KEYSTORE_LOCATION,
	KAFKA_SSL_TRUSTSTORE_LOCATION,
} = require("./env");
const {
	parseListeners,
	parseSecurityMap,
	listenerProtocol,
	protocolRequiresTls,
	protocolRequiresSasl,
	saslMechanismClass,
} = require("./util");
const { parseScramUsers } = require("./validation");

const OWNER = KAFKA_USER + ":" + KAFKA_GROUP;

// readMetaClusterId — the cluster.id line from meta.properties, or "".
function readMetaClusterId() {
	if (!fs.exists(KAFKA_META_PROPERTIES)) return "";
	const content = editor.open(KAFKA_META_PROPERTIES).read();
	for (const line of content.split("\n")) {
		const m = /^cluster\.id=(.+)$/.exec(line.trim());
		if (m) return m[1].trim();
	}
	return "";
}

// readClusterIdFile — the stored cluster id, or "".
function readClusterIdFile() {
	if (!fs.exists(KAFKA_CLUSTER_ID_FILE)) return "";
	return editor.open(KAFKA_CLUSTER_ID_FILE).read().trim();
}

function writeClusterIdFile(id) {
	fs.write(KAFKA_CLUSTER_ID_FILE, id + "\n", { mode: 0o644 });
	fs.chown(KAFKA_CLUSTER_ID_FILE, OWNER);
	fs.chmod(KAFKA_CLUSTER_ID_FILE, 0o644);
}

// resolveClusterId — explicit env > meta.properties > cluster-id file >
// freshly generated. An explicit id that disagrees with the data directory is
// fatal (a mismatch silently corrupts/joins the wrong cluster).
function resolveClusterId() {
	const metaId = readMetaClusterId();
	if (KAFKA_CLUSTER_ID) {
		if (metaId && metaId !== KAFKA_CLUSTER_ID) {
			throw new Error(
				"data directory has cluster id " +
					metaId +
					" but KAFKA_CLUSTER_ID=" +
					KAFKA_CLUSTER_ID +
					"; unset KAFKA_CLUSTER_ID or use a fresh data directory",
			);
		}
		writeClusterIdFile(KAFKA_CLUSTER_ID);
		log.info("Using provided KAFKA_CLUSTER_ID: " + KAFKA_CLUSTER_ID);
		return KAFKA_CLUSTER_ID;
	}
	if (metaId) {
		writeClusterIdFile(metaId);
		log.info("Using cluster id from data directory: " + metaId);
		return metaId;
	}
	const existing = readClusterIdFile();
	if (existing) {
		log.info("Using cluster id from " + KAFKA_CLUSTER_ID_FILE);
		return existing;
	}
	log.info("Generating a new cluster id");
	const res = process.capture({
		name: "kafka-random-uuid",
		process: {
			binaryPath: "kafka-storage.sh",
			arguments: ["random-uuid"],
			user: KAFKA_USER,
			group: KAFKA_GROUP,
		},
	});
	const id = String(res.stdout || "").trim();
	if (res.code !== 0 || id === "") {
		throw new Error("kafka-storage.sh random-uuid failed (code=" + res.code + ")");
	}
	writeClusterIdFile(id);
	log.info("Generated cluster id: " + id);
	return id;
}

// dataDirContents — entries in the data dir, excluding the cluster-id file we
// manage ourselves.
function dataDirContents() {
	if (!fs.exists(KAFKA_DATA_DIR)) return [];
	return fs.readDir(KAFKA_DATA_DIR).filter((n) => n !== "cluster.id");
}

// guardUnformattedDataDir — refuse to format over non-empty, non-KRaft data: a
// mis-mounted or stale volume would otherwise be silently reformatted.
function guardUnformattedDataDir() {
	if (fs.exists(KAFKA_META_PROPERTIES)) return;
	const entries = dataDirContents();
	if (entries.length > 0) {
		throw new Error(
			KAFKA_DATA_DIR +
				" is not empty and not KRaft-formatted (found: " +
				entries.join(", ") +
				"); refusing to format a directory that may contain data",
		);
	}
}

// formatStorage — idempotent format. --ignore-formatted makes a repeat run a
// no-op; a genuine failure still exits non-zero and throws here.
function formatStorage(clusterId) {
	const res = process.capture({
		name: "kafka-storage-format",
		process: {
			binaryPath: "kafka-storage.sh",
			arguments: [
				"format",
				"-t",
				clusterId,
				"-c",
				KAFKA_SERVER_PROPERTIES,
				"--ignore-formatted",
			],
			user: KAFKA_USER,
			group: KAFKA_GROUP,
		},
	});
	if (res.code !== 0) {
		throw new Error(
			"kafka-storage.sh format failed (code=" + res.code + "): " + String(res.stderr || "").trim(),
		);
	}
	log.info("KRaft storage formatted with cluster id " + clusterId);
}

// prepareStorage — resolve the id, guard the data dir, then format. Called
// before the broker starts (format needs the generated server.properties).
function prepareStorage() {
	const id = resolveClusterId();
	guardUnformattedDataDir();
	formatStorage(id);
}

// firstBrokerBootstrap — host:port of the first broker listener for client
// commands (falls back to 127.0.0.1 when the listener binds all interfaces).
function firstBrokerBootstrap() {
	const securityMap = parseSecurityMap(KAFKA_LISTENER_SECURITY_PROTOCOL_MAP);
	const ctl = String(KAFKA_CONTROLLER_LISTENER_NAMES)
		.split(",")
		.map((s) => s.trim().toLowerCase())
		.filter(Boolean);
	for (const l of parseListeners(KAFKA_LISTENERS)) {
		if (!l.valid || !l.port) continue;
		if (ctl.includes(l.name.toLowerCase())) continue; // controller, not broker
		const proto = listenerProtocol(l, securityMap);
		const host = l.host && l.host !== "0.0.0.0" ? l.host : "127.0.0.1";
		return { host: host, port: l.port, protocol: proto };
	}
	return null;
}

// scramClientProps — a minimal client .properties body matching the first
// broker listener's security protocol. Returns null when SASL is required but
// no usable admin JAAS config is available.
function scramClientProps(target) {
	const lines = ["security.protocol=" + target.protocol];
	if (protocolRequiresSasl(target.protocol)) {
		const mech = String(
			KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL ||
				String(KAFKA_SASL_ENABLED_MECHANISMS).split(",")[0] ||
				"SCRAM-SHA-256",
		).toUpperCase();
		// Only SCRAM can authenticate an admin for a SCRAM-alter call.
		if (!mech.startsWith("SCRAM")) return null;
		const user = /username="([^"]+)"/.exec(KAFKA_SASL_JAAS_CONFIG);
		const pass = /password="([^"]+)"/.exec(KAFKA_SASL_JAAS_CONFIG);
		if (!user || !pass) return null;
		lines.push("sasl.mechanism=" + mech);
		lines.push(
			"sasl.jaas.config=" +
				saslMechanismClass(mech) +
				' required username="' +
				user[1] +
				'" password="' +
				pass[1] +
				'";',
		);
	}
	if (protocolRequiresTls(target.protocol) && KAFKA_SSL_ENABLE) {
		lines.push("ssl.truststore.location=" + KAFKA_SSL_TRUSTSTORE_LOCATION);
		lines.push("ssl.keystore.location=" + KAFKA_SSL_KEYSTORE_LOCATION);
		lines.push("ssl.endpoint.identification.algorithm=");
	}
	return lines.join("\n") + "\n";
}

// bootstrapScram — add each configured SCRAM user via kafka-configs.sh. Runs
// once the broker is ready (see runtime.js scramInit). Best-effort: a failure
// is logged, never fatal (the broker is already serving).
function bootstrapScram() {
	const users = parseScramUsers(KAFKA_SASL_SCRAM_USERS);
	if (!users || users.length === 0) return;
	const target = firstBrokerBootstrap();
	if (!target) {
		log.warn("KAFKA_SASL_SCRAM_USERS set but no broker listener found; skipping SCRAM bootstrap");
		return;
	}
	const props = scramClientProps(target);
	if (props === null) {
		log.warn(
			"KAFKA_SASL_SCRAM_USERS set but no SCRAM admin credentials were found in KAFKA_SASL_JAAS_CONFIG; skipping SCRAM bootstrap",
		);
		return;
	}
	const propsFile = "/tmp/kafka-scram-client.properties";
	fs.write(propsFile, props, { mode: 0o600, owner: OWNER });
	for (const u of users) {
		for (const mech of ["SCRAM-SHA-256", "SCRAM-SHA-512"]) {
			const res = process.run({
				name: "kafka-scram-user",
				process: {
					binaryPath: "kafka-configs.sh",
					arguments: [
						"--bootstrap-server",
						target.host + ":" + target.port,
						"--command-config",
						propsFile,
						"--alter",
						"--add-config",
						mech + "=[password=" + u.pass + "]",
						"--entity-type",
						"users",
						"--entity-name",
						u.user,
					],
					user: KAFKA_USER,
					group: KAFKA_GROUP,
				},
			});
			if (res !== 0) {
				log.warn("Failed to set " + mech + " for user " + u.user + " (code=" + res + ")");
			} else {
				log.info("Configured " + mech + " for user " + u.user);
			}
		}
	}
	fs.remove(propsFile);
}

module.exports = {
	prepareStorage,
	resolveClusterId,
	formatStorage,
	guardUnformattedDataDir,
	readMetaClusterId,
	firstBrokerBootstrap,
	bootstrapScram,
};
