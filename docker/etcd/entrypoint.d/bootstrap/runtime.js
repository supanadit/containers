// runtime.js — build the etcd argument matrix and supervise the server.
//
// ezx stays PID 1: it forwards signals, reaps zombies, rotates the log and
// probes readiness. etcd is never exec'd away.
//
// The advertise URLs and initial cluster default to the container's own IP,
// which is resolved once at startup with `hostname -i` (the bash entrypoint did
// the same). The bash entrypoint also unset ETCD_* before exec'ing so etcd's own
// env-based configuration could not re-apply conflicting values; here the
// explicit flag list is the single source, and the node environment is filtered
// of the ETCD_* vars we consume (filterEnvPattern) so the same guarantee holds.
const { process, chain } = require("ezx");
const {
	ETCD_NAME,
	ETCD_DATA_DIR,
	ETCD_USER,
	ETCD_GROUP,
	ETCD_LISTEN_PEER_URLS,
	ETCD_LISTEN_CLIENT_URLS,
	ETCD_ADVERTISE_CLIENT_URLS,
	ETCD_INITIAL_ADVERTISE_PEER_URLS,
	ETCD_INITIAL_CLUSTER,
	ETCD_INITIAL_CLUSTER_STATE,
	ETCD_INITIAL_CLUSTER_TOKEN,
	ETCD_HEARTBEAT_INTERVAL,
	ETCD_ELECTION_TIMEOUT,
	ETCD_SNAPSHOT_COUNT,
	ETCD_AUTO_COMPACTION_RETENTION,
	ETCD_MAX_REQUEST_BYTES,
	ETCD_CERT_FILE,
	ETCD_KEY_FILE,
	ETCD_CLIENT_CERT_AUTH,
	ETCD_TRUSTED_CA_FILE,
	ETCD_PEER_CERT_FILE,
	ETCD_PEER_KEY_FILE,
	ETCD_PEER_CLIENT_CERT_AUTH,
	ETCD_PEER_TRUSTED_CA_FILE,
	ETCD_LOG_DIR,
	ETCD_READY_MAX_ATTEMPTS,
	ETCD_READY_ATTEMPT_INTERVAL,
} = require("./env");

// containerIP — the container's own IP, via `hostname -i` (the bash original).
// Falls back to 127.0.0.1 when the lookup yields nothing.
function containerIP() {
	try {
		const res = process.capture({
			name: "hostname-i",
			process: { binaryPath: "hostname", arguments: ["-i"] },
		});
		const ip = String(res.stdout || "").trim().split(/\s+/)[0];
		return ip || "127.0.0.1";
	} catch (e) {
		return "127.0.0.1";
	}
}

// etcdArguments — the full etcd flag matrix.
function etcdArguments() {
	const ip = containerIP();
	const advertiseClient = ETCD_ADVERTISE_CLIENT_URLS || "http://" + ip + ":2379";
	const advertisePeer = ETCD_INITIAL_ADVERTISE_PEER_URLS || "http://" + ip + ":2380";
	const initialCluster = ETCD_INITIAL_CLUSTER || ETCD_NAME + "=" + advertisePeer;

	const args = [
		"--name=" + ETCD_NAME,
		"--data-dir=" + ETCD_DATA_DIR,
		"--listen-peer-urls=" + ETCD_LISTEN_PEER_URLS,
		"--listen-client-urls=" + ETCD_LISTEN_CLIENT_URLS,
		"--advertise-client-urls=" + advertiseClient,
		"--initial-advertise-peer-urls=" + advertisePeer,
		"--initial-cluster=" + initialCluster,
		"--initial-cluster-state=" + ETCD_INITIAL_CLUSTER_STATE,
		"--initial-cluster-token=" + ETCD_INITIAL_CLUSTER_TOKEN,
		"--heartbeat-interval=" + ETCD_HEARTBEAT_INTERVAL,
		"--election-timeout=" + ETCD_ELECTION_TIMEOUT,
		"--snapshot-count=" + ETCD_SNAPSHOT_COUNT,
		"--auto-compaction-retention=" + ETCD_AUTO_COMPACTION_RETENTION,
		"--max-request-bytes=" + ETCD_MAX_REQUEST_BYTES,
	];

	// TLS flags — every optional flag is guarded (the bash `-n` tests).
	if (ETCD_CERT_FILE) args.push("--cert-file=" + ETCD_CERT_FILE);
	if (ETCD_KEY_FILE) args.push("--key-file=" + ETCD_KEY_FILE);
	if (ETCD_CLIENT_CERT_AUTH) args.push("--client-cert-auth=true");
	if (ETCD_TRUSTED_CA_FILE) args.push("--trusted-ca-file=" + ETCD_TRUSTED_CA_FILE);
	if (ETCD_PEER_CERT_FILE) args.push("--peer-cert-file=" + ETCD_PEER_CERT_FILE);
	if (ETCD_PEER_KEY_FILE) args.push("--peer-key-file=" + ETCD_PEER_KEY_FILE);
	if (ETCD_PEER_CLIENT_CERT_AUTH) args.push("--peer-client-cert-auth=true");
	if (ETCD_PEER_TRUSTED_CA_FILE) args.push("--peer-trusted-ca-file=" + ETCD_PEER_TRUSTED_CA_FILE);

	return args;
}

// etcdClientProto — http or https, from the listen client URL scheme.
function etcdClientProto() {
	return String(ETCD_LISTEN_CLIENT_URLS).trim().startsWith("https") ? "https" : "http";
}

// etcdClientPort — numeric client port parsed from the listen client URL.
function etcdClientPort() {
	const first = String(ETCD_LISTEN_CLIENT_URLS).split(",")[0].trim();
	const m = /:([0-9]+)$/.exec(first);
	return m ? m[1] : "2379";
}

// etcdLog — rotated log (50 MiB x 5).
function etcdLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: ETCD_LOG_DIR + "/etcd.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function etcdNode() {
	return {
		name: "etcd",
		process: {
			binaryPath: "etcd",
			arguments: etcdArguments(),
			user: ETCD_USER,
			group: ETCD_GROUP,
			log: etcdLog(),
			// Strip the ETCD_* vars we consumed so etcd's own env-based
			// configuration cannot re-apply a conflicting value on top of the
			// explicit flags (the bash entrypoint unset them before exec).
			filterEnvPattern: ["^ETCD_"],
		},
		readiness: {
			type: "tcp",
			tcp: { host: "127.0.0.1", port: parseInt(etcdClientPort(), 10) },
			interval: ETCD_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: ETCD_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startEtcd() {
	chain.run({ nodes: [etcdNode()] });
}

// startSleep — hold the container open without starting etcd.
function startSleep() {
	chain.run({
		nodes: [
			{
				name: "sleep",
				process: {},
				restart: { mode: "always", backoff: 1e9 },
			},
		],
	});
}

module.exports = {
	startEtcd,
	startSleep,
	etcdNode,
	etcdArguments,
	etcdLog,
	containerIP,
	etcdClientProto,
	etcdClientPort,
};
