// runtime.js — build the Pyroscope argument matrix and supervise the server.
// ezx stays PID 1: it forwards signals, reaps zombies, rotates the log and
// probes readiness. Pyroscope is never exec'd away.
//
// The per-component flag matrix is a faithful port of the bash case statement,
// including the address defaulting and the >0 guards on numeric knobs. Optional
// flags are guarded so an empty value never emits an empty argument.
const { chain } = require("ezx");
const {
	PYROSCOPE_COMPONENT,
	PYROSCOPE_HTTP_ADDRESS,
	PYROSCOPE_GRPC_ADDRESS,
	PYROSCOPE_DATA_PATH,
	PYROSCOPE_COMPACTOR_DATA_DIR,
	PYROSCOPE_LOG_LEVEL,
	PYROSCOPE_LOG_FORMAT,
	PYROSCOPE_MEMBERLIST_JOIN,
	PYROSCOPE_MEMBERLIST_BIND_PORT,
	PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR,
	PYROSCOPE_MEMBERLIST_ADVERTISE_PORT,
	PYROSCOPE_AUTH_MULTITENANCY_ENABLED,
	PYROSCOPE_STORAGE_BACKEND,
	PYROSCOPE_STORAGE_S3_BUCKET,
	PYROSCOPE_STORAGE_S3_ENDPOINT,
	PYROSCOPE_STORAGE_S3_REGION,
	PYROSCOPE_STORAGE_S3_ACCESS_KEY,
	PYROSCOPE_STORAGE_S3_SECRET_KEY,
	PYROSCOPE_STORAGE_S3_INSECURE,
	PYROSCOPE_STORAGE_GCS_BUCKET,
	PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT,
	PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME,
	PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY,
	PYROSCOPE_STORAGE_AZURE_CONTAINER,
	PYROSCOPE_STORAGE_FILESYSTEM_DIR,
	PYROSCOPE_STORAGE_PREFIX,
	PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR,
	PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB,
	PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB,
	PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED,
	PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT,
	PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT,
	PYROSCOPE_INGESTER_AVAILABILITY_ZONE,
	PYROSCOPE_COMPACTOR_RETENTION_PERIOD,
	PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED,
	PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE,
	PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED,
	PYROSCOPE_QUERIER_MAX_QUERY_LENGTH,
	PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK,
	PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM,
	PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL,
	PYROSCOPE_QUERY_FRONTEND_ADDRESS,
	PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS,
	PYROSCOPE_LOG_DIR,
	PYROSCOPE_USER,
	PYROSCOPE_GROUP,
	PYROSCOPE_BIN,
	COMPONENT_DEFAULTS,
	PYROSCOPE_READY_MAX_ATTEMPTS,
	PYROSCOPE_READY_ATTEMPT_INTERVAL,
} = require("./env");

// stripColon — ":4040" -> "4040" (the bash ${VAR#:}).
function stripColon(v) {
	return String(v).replace(/^:/, "");
}

// pyroscopeArguments — the full argument vector for the selected component.
function pyroscopeArguments() {
	const args = [
		"-log.level=" + PYROSCOPE_LOG_LEVEL,
		"-log.format=" + PYROSCOPE_LOG_FORMAT,
	];

	// Component-specific address defaults (the bash case assigned them before
	// the shared address flags were evaluated).
	const defaults = COMPONENT_DEFAULTS[PYROSCOPE_COMPONENT] || { http: "", grpc: "" };
	let httpAddr = PYROSCOPE_HTTP_ADDRESS;
	let grpcAddr = PYROSCOPE_GRPC_ADDRESS;
	if (!httpAddr && defaults.http) httpAddr = defaults.http;
	if (!grpcAddr && defaults.grpc) grpcAddr = defaults.grpc;

	if (httpAddr) args.push("-server.http-listen-port=" + stripColon(httpAddr));
	if (grpcAddr) args.push("-server.grpc-listen-port=" + stripColon(grpcAddr));

	if (PYROSCOPE_AUTH_MULTITENANCY_ENABLED) args.push("-auth.multitenancy-enabled");

	if (PYROSCOPE_MEMBERLIST_JOIN) {
		for (const m of String(PYROSCOPE_MEMBERLIST_JOIN).split(",")) {
			const member = m.trim();
			if (member) args.push("-memberlist.join=" + member);
		}
	}
	if (PYROSCOPE_MEMBERLIST_BIND_PORT) args.push("-memberlist.bind-port=" + PYROSCOPE_MEMBERLIST_BIND_PORT);
	if (PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR) args.push("-memberlist.advertise-addr=" + PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR);
	if (PYROSCOPE_MEMBERLIST_ADVERTISE_PORT) args.push("-memberlist.advertise-port=" + PYROSCOPE_MEMBERLIST_ADVERTISE_PORT);

	if (PYROSCOPE_STORAGE_BACKEND) {
		args.push("-storage.backend=" + PYROSCOPE_STORAGE_BACKEND);
		if (PYROSCOPE_STORAGE_BACKEND === "s3") {
			if (PYROSCOPE_STORAGE_S3_BUCKET) args.push("-storage.s3.bucket-name=" + PYROSCOPE_STORAGE_S3_BUCKET);
			if (PYROSCOPE_STORAGE_S3_ENDPOINT) args.push("-storage.s3.endpoint=" + PYROSCOPE_STORAGE_S3_ENDPOINT);
			if (PYROSCOPE_STORAGE_S3_REGION) args.push("-storage.s3.region=" + PYROSCOPE_STORAGE_S3_REGION);
			if (PYROSCOPE_STORAGE_S3_ACCESS_KEY) args.push("-storage.s3.access-key-id=" + PYROSCOPE_STORAGE_S3_ACCESS_KEY);
			if (PYROSCOPE_STORAGE_S3_SECRET_KEY) args.push("-storage.s3.secret-access-key=" + PYROSCOPE_STORAGE_S3_SECRET_KEY);
			if (PYROSCOPE_STORAGE_S3_INSECURE) args.push("-storage.s3.insecure");
		}
		if (PYROSCOPE_STORAGE_BACKEND === "gcs") {
			if (PYROSCOPE_STORAGE_GCS_BUCKET) args.push("-storage.gcs.bucket-name=" + PYROSCOPE_STORAGE_GCS_BUCKET);
			if (PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT) args.push("-storage.gcs.service-account=" + PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT);
		}
		if (PYROSCOPE_STORAGE_BACKEND === "azure") {
			if (PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME) args.push("-storage.azure.account-name=" + PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME);
			if (PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY) args.push("-storage.azure.account-key=" + PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY);
			if (PYROSCOPE_STORAGE_AZURE_CONTAINER) args.push("-storage.azure.container-name=" + PYROSCOPE_STORAGE_AZURE_CONTAINER);
		}
		if (PYROSCOPE_STORAGE_BACKEND === "filesystem") {
			args.push("-storage.filesystem.dir=" + PYROSCOPE_STORAGE_FILESYSTEM_DIR);
		}
	}

	if (PYROSCOPE_STORAGE_PREFIX) args.push("-storage.prefix=" + PYROSCOPE_STORAGE_PREFIX);

	switch (PYROSCOPE_COMPONENT) {
		case "all":
			args.push("-target=all");
			args.push("-pyroscopedb.data-path=" + PYROSCOPE_DATA_PATH);
			break;
		case "distributor":
			args.push("-target=distributor");
			args.push("-distributor.replication-factor=" + PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR);
			args.push("-distributor.ingestion-rate-limit-mb=" + PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB);
			args.push("-distributor.ingestion-burst-size-mb=" + PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB);
			if (PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED) args.push("-distributor.zone-awareness-enabled");
			break;
		case "ingester":
			args.push("-target=ingester");
			args.push("-pyroscopedb.data-path=" + PYROSCOPE_DATA_PATH);
			if (parseInt(PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT, 10) > 0) {
				args.push("-ingester.max-global-series-per-tenant=" + PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT);
			}
			if (parseInt(PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT, 10) > 0) {
				args.push("-ingester.max-local-series-per-tenant=" + PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT);
			}
			if (PYROSCOPE_INGESTER_AVAILABILITY_ZONE) args.push("-ingester.availability-zone=" + PYROSCOPE_INGESTER_AVAILABILITY_ZONE);
			break;
		case "compactor":
			args.push("-target=compactor");
			args.push("-compactor.data-dir=" + PYROSCOPE_COMPACTOR_DATA_DIR);
			if (PYROSCOPE_COMPACTOR_RETENTION_PERIOD) args.push("-compactor.blocks-retention-period=" + PYROSCOPE_COMPACTOR_RETENTION_PERIOD);
			if (PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED) args.push("-compactor.compactor-downsampler-enabled");
			break;
		case "querier":
			args.push("-target=querier");
			if (PYROSCOPE_QUERIER_MAX_QUERY_LENGTH) args.push("-querier.max-query-length=" + PYROSCOPE_QUERIER_MAX_QUERY_LENGTH);
			if (PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK) args.push("-querier.max-query-lookback=" + PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK);
			if (parseInt(PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM, 10) > 0) {
				args.push("-querier.max-query-parallelism=" + PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM);
			}
			if (PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL) args.push("-querier.split-queries-by-interval=" + PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL);
			break;
		case "store-gateway":
			args.push("-target=store-gateway");
			if (parseInt(PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE, 10) > 0) {
				args.push("-store-gateway.tenant-shard-size=" + PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE);
			}
			if (PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED) args.push("-store-gateway.sharding-ring.zone-awareness-enabled");
			break;
		case "query-frontend":
			args.push("-target=query-frontend");
			if (PYROSCOPE_QUERY_FRONTEND_ADDRESS) args.push("-query-frontend.address=" + PYROSCOPE_QUERY_FRONTEND_ADDRESS);
			break;
		case "query-scheduler":
			args.push("-target=query-scheduler");
			if (parseInt(PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS, 10) > 0) {
				args.push("-query-scheduler.max-outstanding-requests-per-tenant=" + PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS);
			}
			break;
	}

	return args;
}

// pyroscopeHTTPPort — the port Pyroscope exposes its HTTP API on, for probes.
function pyroscopeHTTPPort() {
	if (PYROSCOPE_HTTP_ADDRESS) return stripColon(PYROSCOPE_HTTP_ADDRESS);
	const defaults = COMPONENT_DEFAULTS[PYROSCOPE_COMPONENT] || { http: "" };
	return defaults.http ? stripColon(defaults.http) : "4040";
}

function pyroscopeLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: PYROSCOPE_LOG_DIR + "/pyroscope.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function pyroscopeNode() {
	return {
		name: "pyroscope",
		process: {
			binaryPath: PYROSCOPE_BIN,
			arguments: pyroscopeArguments(),
			user: PYROSCOPE_USER,
			group: PYROSCOPE_GROUP,
			log: pyroscopeLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + pyroscopeHTTPPort() + "/ready", expectStatus: 200 },
			interval: PYROSCOPE_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: PYROSCOPE_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startPyroscope() {
	chain.run({ nodes: [pyroscopeNode()] });
}

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
	startPyroscope,
	startSleep,
	pyroscopeNode,
	pyroscopeArguments,
	pyroscopeHTTPPort,
	pyroscopeLog,
	stripColon,
};
