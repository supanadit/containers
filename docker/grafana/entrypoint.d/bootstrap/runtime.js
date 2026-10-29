// runtime.js — supervise the Grafana server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness. Grafana is
// never exec'd away.
const { chain } = require("ezx");
const {
	GRAFANA_HOME,
	GRAFANA_PORT,
	GRAFANA_CONFIG_FILE,
	GRAFANA_DATA_DIR,
	GRAFANA_LOG_DIR,
	GRAFANA_PLUGINS_DIR,
	GRAFANA_PROVISIONING_DIR,
	GRAFANA_PACKAGING,
	GRAFANA_USER,
	GRAFANA_GROUP,
	GRAFANA_READY_MAX_ATTEMPTS,
	GRAFANA_READY_ATTEMPT_INTERVAL,
} = require("./env");

// grafanaArguments — the server flag matrix. Grafana is configured through the
// config file plus cfg:default.* overrides; the plugin/provisioning paths are
// pinned so a bare container gets a working layout on the normalized volumes.
function grafanaArguments() {
	return [
		"server",
		"--homepath=" + GRAFANA_HOME,
		"--config=" + GRAFANA_CONFIG_FILE,
		"--packaging=" + GRAFANA_PACKAGING,
		"cfg:default.paths.data=" + GRAFANA_DATA_DIR,
		"cfg:default.paths.logs=" + GRAFANA_LOG_DIR,
		"cfg:default.paths.plugins=" + GRAFANA_PLUGINS_DIR,
		"cfg:default.paths.provisioning=" + GRAFANA_PROVISIONING_DIR,
	];
}

// grafanaLog — rotated log (50 MiB x 5).
function grafanaLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: GRAFANA_LOG_DIR + "/grafana.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// grafanaNode — the supervised Grafana server.
function grafanaNode() {
	return {
		name: "grafana",
		process: {
			binaryPath: "grafana",
			arguments: grafanaArguments(),
			user: GRAFANA_USER,
			group: GRAFANA_GROUP,
			log: grafanaLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + GRAFANA_PORT + "/api/health", expectStatus: 200 },
			interval: GRAFANA_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: GRAFANA_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startGrafana() {
	chain.run({ nodes: [grafanaNode()] });
}

// startSleep — hold the container open without starting Grafana.
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
	startGrafana,
	startSleep,
	grafanaNode,
	grafanaArguments,
	grafanaLog,
};
