// runtime.js — supervise the Tempo server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
const { chain } = require("ezx");
const {
	GRAFANA_TEMPO_CONFIG,
	GRAFANA_TEMPO_LOG_DIR,
	GRAFANA_TEMPO_USER,
	GRAFANA_TEMPO_GROUP,
	GRAFANA_TEMPO_LISTEN_PORT_HTTP,
	GRAFANA_TEMPO_TARGET,
	GRAFANA_TEMPO_READY_MAX_ATTEMPTS,
	GRAFANA_TEMPO_READY_ATTEMPT_INTERVAL,
} = require("./env");

// tempoArguments — the CLI flag matrix.
function tempoArguments() {
	return [
		"-target=" + GRAFANA_TEMPO_TARGET,
		"-config.file=" + GRAFANA_TEMPO_CONFIG,
	];
}

function tempoLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: GRAFANA_TEMPO_LOG_DIR + "/tempo.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function tempoNode() {
	return {
		name: "tempo",
		process: {
			binaryPath: "tempo",
			arguments: tempoArguments(),
			user: GRAFANA_TEMPO_USER,
			group: GRAFANA_TEMPO_GROUP,
			log: tempoLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + GRAFANA_TEMPO_LISTEN_PORT_HTTP + "/ready", expectStatus: 200 },
			interval: GRAFANA_TEMPO_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: GRAFANA_TEMPO_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startTempo() {
	chain.run({ nodes: [tempoNode()] });
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
	startTempo,
	startSleep,
	tempoNode,
	tempoArguments,
	tempoLog,
};
