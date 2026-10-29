// runtime.js — supervise the MinIO server. ezx stays PID 1: it forwards signals,
// reaps zombies, rotates the log and probes readiness. MinIO is never exec'd
// away, and the arbitrary-command pass-through the bash entrypoint offered
// (`docker run <image> <cmd>`) is intentionally gone — with a PID-1 supervisor
// the supported way to run admin commands is `docker exec` (mc/promtool etc.).
const { chain } = require("ezx");
const {
	MINIO_DATA_DIR,
	MINIO_LOG_DIR,
	MINIO_USER,
	MINIO_GROUP,
	MINIO_ADDRESS,
	MINIO_CONSOLE_ADDRESS,
	MINIO_DISTRIBUTED_MODE_ENABLED,
	MINIO_DISTRIBUTED_NODES,
	MINIO_EXTRA_DRIVES,
	MINIO_EXTRA_ARGS,
	MINIO_READY_MAX_ATTEMPTS,
	MINIO_READY_ATTEMPT_INTERVAL,
	splitList,
	portOf,
} = require("./env");
const { browserRedirectUrl, materializeCredentials, runtimeEnvironment, filterEnvPatterns } = require("./config");

// driveArgs — the drive paths MinIO is told to serve. Distributed mode uses the
// operator's expansion verbatim; standalone mode uses the data dir plus any extra
// drives.
function driveArgs() {
	if (MINIO_DISTRIBUTED_MODE_ENABLED) {
		return splitList(MINIO_DISTRIBUTED_NODES);
	}
	return [MINIO_DATA_DIR].concat(splitList(MINIO_EXTRA_DRIVES));
}

// serverArguments — the full argv after "server": the drive list follows the
// subcommand, then the listener flags.
function serverArguments() {
	const args = ["server"];
	for (const drive of driveArgs()) {
		args.push(drive);
	}
	args.push("--address=" + MINIO_ADDRESS);
	if (MINIO_CONSOLE_ADDRESS) {
		args.push("--console-address=" + MINIO_CONSOLE_ADDRESS);
	}
	for (const extra of splitList(MINIO_EXTRA_ARGS)) {
		args.push(extra);
	}
	return args;
}

// minioLog — rotated log (50 MiB x 5).
function minioLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: MINIO_LOG_DIR + "/minio.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// minioNode — the supervised MinIO server. The caller passes the credentials
// resolved in main.js so the inline secrets are replaced by *_FILE paths before
// the process environment is built.
function minioNode(creds) {
	const redirectUrl = browserRedirectUrl();
	return {
		name: "minio",
		process: {
			binaryPath: "minio",
			arguments: serverArguments(),
			user: MINIO_USER,
			group: MINIO_GROUP,
			environment: runtimeEnvironment(creds, redirectUrl),
			// Never hand the container's own MINIO_* configuration to MinIO.
			filterEnvPattern: filterEnvPatterns(),
			log: minioLog(),
		},
		readiness: {
			type: "http",
			http: {
				url: "http://127.0.0.1:" + portOf(MINIO_ADDRESS) + "/minio/health/ready",
				expectStatus: 200,
			},
			interval: MINIO_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: MINIO_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 30e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

// startMinio — build credentials, then supervise MinIO.
function startMinio() {
	const creds = materializeCredentials();
	chain.run({ nodes: [minioNode(creds)] });
}

// startSleep — hold the container open without starting MinIO.
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
	startMinio,
	startSleep,
	minioNode,
	serverArguments,
	driveArgs,
	minioLog,
};
