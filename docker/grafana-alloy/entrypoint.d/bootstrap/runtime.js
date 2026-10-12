// runtime.js — supervise the Alloy collector. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness. Alloy is never
// exec'd away.
const { chain } = require("ezx");
const {
	GRAFANA_ALLOY_CONFIG,
	GRAFANA_ALLOY_DATA_DIR,
	GRAFANA_ALLOY_LOG_DIR,
	GRAFANA_ALLOY_USER,
	GRAFANA_ALLOY_GROUP,
	GRAFANA_ALLOY_HTTP_LISTEN_ADDR,
	GRAFANA_ALLOY_EXPERIMENTAL_FEATURES,
	GRAFANA_ALLOY_STABILITY_LEVEL,
	GRAFANA_ALLOY_READY_MAX_ATTEMPTS,
	GRAFANA_ALLOY_READY_ATTEMPT_INTERVAL,
	httpPort,
} = require("./env");

// alloyArguments — the run flag matrix.
function alloyArguments() {
	const args = [
		"run",
		GRAFANA_ALLOY_CONFIG,
		"--storage.path=" + GRAFANA_ALLOY_DATA_DIR,
		"--server.http.listen-addr=" + GRAFANA_ALLOY_HTTP_LISTEN_ADDR,
	];
	// Guard the optional stability flag: an empty value still emits an argument.
	if (GRAFANA_ALLOY_EXPERIMENTAL_FEATURES && GRAFANA_ALLOY_STABILITY_LEVEL) {
		args.push("--stability.level=" + GRAFANA_ALLOY_STABILITY_LEVEL);
	}
	return args;
}

function alloyLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: GRAFANA_ALLOY_LOG_DIR + "/alloy.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function alloyNode() {
	return {
		name: "alloy",
		process: {
			binaryPath: "alloy",
			arguments: alloyArguments(),
			user: GRAFANA_ALLOY_USER,
			group: GRAFANA_ALLOY_GROUP,
			log: alloyLog(),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + httpPort() + "/-/ready", expectStatus: 200 },
			interval: GRAFANA_ALLOY_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: GRAFANA_ALLOY_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startAlloy() {
	chain.run({ nodes: [alloyNode()] });
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
	startAlloy,
	startSleep,
	alloyNode,
	alloyArguments,
	alloyLog,
};
