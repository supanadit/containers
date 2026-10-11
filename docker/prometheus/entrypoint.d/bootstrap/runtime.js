// runtime.js — supervise the Prometheus server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness. Prometheus is
// never exec'd away.
//
// The flag matrix is built declaratively with process.argOperations: the
// per-feature --enable-feature flags come from the PROMETHEUS_FEATURES table in
// env.js, the boolean web toggles are gated with `when`, and the storage
// settings are only added when non-empty.
const { chain } = require("ezx");
const {
	PROMETHEUS_PORT,
	PROMETHEUS_CONFIG_FILE,
	PROMETHEUS_WEB_CONFIG_FILE,
	PROMETHEUS_DATA_DIR,
	PROMETHEUS_LOG_DIR,
	PROMETHEUS_USER,
	PROMETHEUS_GROUP,
	PROMETHEUS_FEATURES,
	PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION,
	PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION,
	PROMETHEUS_STORAGE_TSDB_RETENTION_TIME,
	PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE,
	PROMETHEUS_READY_MAX_ATTEMPTS,
	PROMETHEUS_READY_ATTEMPT_INTERVAL,
} = require("./env");

// prometheusArgOperations — the Prometheus CLI flag matrix.
function prometheusArgOperations() {
	const ops = [
		{ flag: "--config.file", value: PROMETHEUS_CONFIG_FILE },
		{ flag: "--storage.tsdb.path", value: PROMETHEUS_DATA_DIR },
		{ flag: "--web.listen-address", value: ":" + PROMETHEUS_PORT },
	];

	// Optional TLS / auth config for the web endpoint.
	ops.push({ flag: "--web.config.file", value: PROMETHEUS_WEB_CONFIG_FILE });

	// TSDB block durations / retention (only when set).
	ops.push({ flag: "--storage.tsdb.min-block-duration", value: PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION });
	ops.push({ flag: "--storage.tsdb.max-block-duration", value: PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION });
	ops.push({ flag: "--storage.tsdb.retention.time", value: PROMETHEUS_STORAGE_TSDB_RETENTION_TIME });
	ops.push({ flag: "--storage.tsdb.retention.size", value: PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE });

	// Feature flags: one declarative row per enabled feature (env.js already
	// filtered the table, so these are literals).
	for (const f of PROMETHEUS_FEATURES) {
		ops.push({ flag: "--enable-feature", value: f.feature });
	}

	return ops;
}

// prometheusLog — rotated log (50 MiB x 5).
function prometheusLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: PROMETHEUS_LOG_DIR + "/prometheus.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// prometheusNode — the supervised Prometheus server.
function prometheusNode() {
	return {
		name: "prometheus",
		process: {
			binaryPath: "prometheus",
			argOperations: prometheusArgOperations(),
			user: PROMETHEUS_USER,
			group: PROMETHEUS_GROUP,
			log: prometheusLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + PROMETHEUS_PORT + "/-/ready", expectStatus: 200 },
			interval: PROMETHEUS_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: PROMETHEUS_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startPrometheus() {
	chain.run({ nodes: [prometheusNode()] });
}

// startSleep — hold the container open without starting Prometheus.
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
	startPrometheus,
	startSleep,
	prometheusNode,
	prometheusArgOperations,
	prometheusLog,
};
