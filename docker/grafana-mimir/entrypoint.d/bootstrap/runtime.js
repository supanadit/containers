// runtime.js — supervise the Mimir server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
const { chain } = require("ezx");
const {
	GRAFANA_MIMIR_CONFIG,
	GRAFANA_MIMIR_LOG_DIR,
	GRAFANA_MIMIR_USER,
	GRAFANA_MIMIR_GROUP,
	GRAFANA_MIMIR_EXTRA_ARGS,
	MIMIR_BIN,
	MIMIR_HTTP_PORT,
	GRAFANA_MIMIR_READY_MAX_ATTEMPTS,
	GRAFANA_MIMIR_READY_ATTEMPT_INTERVAL,
} = require("./env");

// mimirArguments — the CLI flag matrix plus any whitespace-split extra args.
function mimirArguments() {
	const args = ["--config.file=" + GRAFANA_MIMIR_CONFIG];
	// GRAFANA_MIMIR_EXTRA_ARGS is a whitespace-separated pass-through, exactly
	// as the bash entrypoint read -a'd it. An empty value adds nothing.
	if (String(GRAFANA_MIMIR_EXTRA_ARGS).trim() !== "") {
		for (const a of String(GRAFANA_MIMIR_EXTRA_ARGS).trim().split(/\s+/)) args.push(a);
	}
	return args;
}

function mimirLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: GRAFANA_MIMIR_LOG_DIR + "/mimir.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function mimirNode() {
	return {
		name: "mimir",
		process: {
			binaryPath: MIMIR_BIN,
			arguments: mimirArguments(),
			user: GRAFANA_MIMIR_USER,
			group: GRAFANA_MIMIR_GROUP,
			log: mimirLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + MIMIR_HTTP_PORT + "/ready", expectStatus: 200 },
			interval: GRAFANA_MIMIR_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: GRAFANA_MIMIR_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startMimir() {
	chain.run({ nodes: [mimirNode()] });
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
	startMimir,
	startSleep,
	mimirNode,
	mimirArguments,
	mimirLog,
};
