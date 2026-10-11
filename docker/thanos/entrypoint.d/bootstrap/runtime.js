// runtime.js — supervise the selected Thanos component. ezx stays PID 1:
// it forwards signals, reaps zombies, rotates the log and probes readiness.
// Nothing is exec'd away.
//
// The component flag matrix is built declaratively with process.argOperations
// (see the ezx docs): conditional flags use `when`, comma-separated endpoints
// use `fromEnv` + `split`, and the per-label external labels use
// `fromEnvPattern` + `nameTransform` — replacing the bash `env | grep | tr`
// loop with no shell.
const { chain } = require("ezx");
const {
	THANOS_COMPONENT,
	THANOS_HTTP_ADDRESS,
	THANOS_GRPC_ADDRESS,
	THANOS_DATA_DIR,
	THANOS_LOG_DIR,
	THANOS_USER,
	THANOS_GROUP,
	THANOS_REPLICA_LABEL,
	THANOS_QUERY_FRONTEND_DOWNSTREAM_URL,
	THANOS_QUERY_RANGE_SPLIT_INTERVAL,
	THANOS_QUERY_RANGE_MAX_RETRIES,
	THANOS_LABELS_SPLIT_INTERVAL,
	THANOS_CACHE_CONFIG_FILE,
	THANOS_STORE_INDEX_CACHE_CONFIG,
	THANOS_STORE_INDEX_CACHE_CONFIG_FILE,
	THANOS_STORE_CACHING_BUCKET_CONFIG,
	THANOS_STORE_CACHING_BUCKET_CONFIG_FILE,
	THANOS_COMPACT_DOWNSAMPLING_DISABLE,
	THANOS_COMPACT_RETENTION_RAW,
	THANOS_COMPACT_RETENTION_5M,
	THANOS_COMPACT_RETENTION_1H,
	THANOS_COMPACT_CONSISTENCY_DELAY,
	THANOS_COMPACT_COMPACTION_CONCURRENCY,
	THANOS_SIDECAR_PROMETHEUS_URL,
	THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED,
	THANOS_RECEIVE_REPLICATION_FACTOR,
	THANOS_RECEIVE_LOCAL_ENDPOINT,
	THANOS_RECEIVE_HASHRING_FILE,
	THANOS_REMOTE_WRITE_ADDRESS,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE,
	THANOS_READY_MAX_ATTEMPTS,
	THANOS_READY_ATTEMPT_INTERVAL,
	httpPort,
} = require("./env");
const { configFiles, objstoreArg } = require("./config");
const { OBJSTORE_COMPONENTS } = require("./validation");

// GRPC_COMPONENTS — the components that accept --grpc-address.
const GRPC_COMPONENTS = ["query", "sidecar", "store", "receive", "rule"];

// componentArgOperations — the per-component flag matrix.
function componentArgOperations() {
	const ops = [];

	// Common: the HTTP address is always present.
	ops.push({ flag: "--http-address", value: THANOS_HTTP_ADDRESS });
	if (GRPC_COMPONENTS.includes(THANOS_COMPONENT)) {
		ops.push({ flag: "--grpc-address", value: THANOS_GRPC_ADDRESS });
	}

	switch (THANOS_COMPONENT) {
		case "query":
			if (THANOS_REPLICA_LABEL) {
				ops.push({ flag: "--query.replica-label", value: THANOS_REPLICA_LABEL });
			}
			ops.push({ flag: "--endpoint", fromEnv: "THANOS_QUERY_STORE_ADDRESSES", split: "," });
			break;

		case "sidecar":
			ops.push({ flag: "--prometheus.url", value: THANOS_SIDECAR_PROMETHEUS_URL });
			ops.push({ flag: "--tsdb.path", value: THANOS_DATA_DIR });
			if (THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED) {
				ops.push({ flag: "--shipper.upload-compacted", format: "bare-flag", value: "true" });
			}
			break;

		case "store":
			ops.push({ flag: "--data-dir", value: THANOS_DATA_DIR });
			// Optional flags must be guarded: `value: ""` emits `--flag=`, an empty
			// argument. The pre-migration entrypoint guarded every one with `-n`.
			// Index cache: an inline config wins over a file (the old if/elif).
			if (THANOS_STORE_INDEX_CACHE_CONFIG) {
				ops.push({ flag: "--index-cache.config", value: THANOS_STORE_INDEX_CACHE_CONFIG });
			} else if (THANOS_STORE_INDEX_CACHE_CONFIG_FILE) {
				ops.push({ flag: "--index-cache.config-file", value: THANOS_STORE_INDEX_CACHE_CONFIG_FILE });
			}
			// Caching bucket: inline config wins over a file.
			if (THANOS_STORE_CACHING_BUCKET_CONFIG) {
				ops.push({ flag: "--store.caching-bucket.config", value: THANOS_STORE_CACHING_BUCKET_CONFIG });
			} else if (THANOS_STORE_CACHING_BUCKET_CONFIG_FILE) {
				ops.push({
					flag: "--store.caching-bucket.config-file",
					value: THANOS_STORE_CACHING_BUCKET_CONFIG_FILE,
				});
			}
			break;

		case "query-frontend":
			if (THANOS_QUERY_FRONTEND_DOWNSTREAM_URL) {
				ops.push({ flag: "--query-frontend.downstream-url", value: THANOS_QUERY_FRONTEND_DOWNSTREAM_URL });
			}
			if (THANOS_QUERY_RANGE_SPLIT_INTERVAL) {
				ops.push({ flag: "--query-range.split-interval", value: THANOS_QUERY_RANGE_SPLIT_INTERVAL });
			}
			if (THANOS_QUERY_RANGE_MAX_RETRIES) {
				ops.push({ flag: "--query-range.max-retries-per-request", value: THANOS_QUERY_RANGE_MAX_RETRIES });
			}
			if (THANOS_LABELS_SPLIT_INTERVAL) {
				ops.push({ flag: "--labels.split-interval", value: THANOS_LABELS_SPLIT_INTERVAL });
			}
			// An inline response-cache config was written to the config volume at
			// provisioning time; it wins over an explicitly mounted file.
			if (THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG) {
				ops.push({ flag: "--query-range.response-cache-config-file", value: THANOS_CACHE_CONFIG_FILE });
			} else if (THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE) {
				ops.push({
					flag: "--query-range.response-cache-config-file",
					value: THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG_FILE,
				});
			}
			break;

		case "compact":
			ops.push({ flag: "--data-dir", value: THANOS_DATA_DIR });
			if (THANOS_COMPACT_DOWNSAMPLING_DISABLE) {
				ops.push({ flag: "--downsampling.disable", format: "bare-flag", value: "true" });
			}
			if (THANOS_COMPACT_RETENTION_RAW) {
				ops.push({ flag: "--retention.resolution-raw", value: THANOS_COMPACT_RETENTION_RAW });
			}
			if (THANOS_COMPACT_RETENTION_5M) {
				ops.push({ flag: "--retention.resolution-5m", value: THANOS_COMPACT_RETENTION_5M });
			}
			if (THANOS_COMPACT_RETENTION_1H) {
				ops.push({ flag: "--retention.resolution-1h", value: THANOS_COMPACT_RETENTION_1H });
			}
			if (THANOS_COMPACT_CONSISTENCY_DELAY) {
				ops.push({ flag: "--consistency-delay", value: THANOS_COMPACT_CONSISTENCY_DELAY });
			}
			if (THANOS_COMPACT_COMPACTION_CONCURRENCY) {
				ops.push({ flag: "--compact.concurrency", value: THANOS_COMPACT_COMPACTION_CONCURRENCY });
			}
			// The bash entrypoint always added --wait for compact.
			ops.push({ flag: "--wait", format: "bare-flag", value: "true" });
			break;

		case "receive":
			ops.push({ flag: "--tsdb.path", value: THANOS_DATA_DIR });
			ops.push({
				flag: "--receive.replication-factor",
				value: THANOS_RECEIVE_REPLICATION_FACTOR,
			});
			ops.push({ flag: "--receive.local-endpoint", value: THANOS_RECEIVE_LOCAL_ENDPOINT });
			ops.push({ flag: "--remote-write.address", value: THANOS_REMOTE_WRITE_ADDRESS });
			if (THANOS_RECEIVE_HASHRING_FILE) {
				ops.push({ flag: "--receive.hashring-file", value: THANOS_RECEIVE_HASHRING_FILE });
			}
			// External labels from THANOS_RECEIVE_LABELS_<NAME> (uppercase snake
			// in the var, lowercased for the label name).
			ops.push({
				flag: "--label",
				fromEnvPattern: "^THANOS_RECEIVE_LABELS_(.+)$",
				nameTransform: "lower",
				value: '${name}="${value}"',
			});
			break;

		case "rule":
			ops.push({ flag: "--data-dir", value: THANOS_DATA_DIR });
			ops.push({ flag: "--query", fromEnv: "THANOS_QUERY_ENDPOINTS", split: "," });
			ops.push({ flag: "--rule-file", fromEnv: "THANOS_RULE_FILES", split: "," });
			ops.push({ flag: "--alertmanagers.url", fromEnv: "THANOS_ALERTMANAGERS_URL", split: "," });
			break;
	}

	// Object store: only the components that read one.
	if (OBJSTORE_COMPONENTS.includes(THANOS_COMPONENT)) {
		const arg = objstoreArg();
		if (arg) ops.push({ flag: arg.flag, value: arg.value });
	}

	return ops;
}

// thanosLog — per-component rotated log (50 MiB x 5).
function thanosLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: THANOS_LOG_DIR + "/thanos-" + THANOS_COMPONENT + ".log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// thanosNode — the supervised Thanos component.
function thanosNode() {
	return {
		name: "thanos",
		files: configFiles(),
		process: {
			binaryPath: "thanos",
			// The subcommand ("query", "store", ...) precedes the flags.
			arguments: [THANOS_COMPONENT],
			argOperations: componentArgOperations(),
			user: THANOS_USER,
			group: THANOS_GROUP,
			log: thanosLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + httpPort() + "/-/ready", expectStatus: 200 },
			interval: THANOS_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: THANOS_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startThanos() {
	chain.run({ nodes: [thanosNode()] });
}

// startSleep — hold the container open without starting Thanos.
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
	startThanos,
	startSleep,
	thanosNode,
	componentArgOperations,
	thanosLog,
};
