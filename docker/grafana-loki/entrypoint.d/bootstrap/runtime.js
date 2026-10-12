// runtime.js — supervise the Loki server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
const { chain } = require("ezx");
const {
	GRAFANA_LOKI_CONFIG,
	GRAFANA_LOKI_LOG_DIR,
	GRAFANA_LOKI_USER,
	GRAFANA_LOKI_GROUP,
	GRAFANA_LOKI_LISTEN_PORT_HTTP,
	GRAFANA_LOKI_TARGET,
	GRAFANA_LOKI_READY_MAX_ATTEMPTS,
	GRAFANA_LOKI_READY_ATTEMPT_INTERVAL,
} = require("./env");

// lokiArguments — the CLI flag matrix.
function lokiArguments() {
	const args = ["-config.file=" + GRAFANA_LOKI_CONFIG];
	if (GRAFANA_LOKI_TARGET) {
		args.push("-target=" + GRAFANA_LOKI_TARGET);
		// The backend target needs legacy read mode disabled for the
		// microservices deployment mode.
		if (GRAFANA_LOKI_TARGET === "backend") {
			args.push("-legacy-read-mode=false");
		}
	}
	return args;
}

function lokiLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: GRAFANA_LOKI_LOG_DIR + "/loki.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function lokiNode() {
	return {
		name: "loki",
		process: {
			binaryPath: "loki",
			arguments: lokiArguments(),
			user: GRAFANA_LOKI_USER,
			group: GRAFANA_LOKI_GROUP,
			log: lokiLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + GRAFANA_LOKI_LISTEN_PORT_HTTP + "/ready", expectStatus: 200 },
			interval: GRAFANA_LOKI_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: GRAFANA_LOKI_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startLoki() {
	chain.run({ nodes: [lokiNode()] });
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
	startLoki,
	startSleep,
	lokiNode,
	lokiArguments,
	lokiLog,
};
