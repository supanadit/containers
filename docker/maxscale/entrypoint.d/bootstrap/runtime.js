// runtime.js — supervise MaxScale. ezx stays PID 1: it forwards signals, reaps
// zombies, rotates the log and probes readiness.
//
// The bash entrypoint `exec gosu maxscale maxscale -d -l stdout -f <cnf>`. ezx
// drops privileges via process.user/group, replacing gosu. MaxScale is run in
// the foreground so ezx can supervise it.
const { chain } = require("ezx");
const {
	MAXSCALE_CONFIG_FILE,
	MAXSCALE_LOG_DIR,
	MAXSCALE_READY_MAX_ATTEMPTS,
	MAXSCALE_READY_ATTEMPT_INTERVAL,
	MAXSCALE_REST_PORT,
} = require("./env");

function maxscaleArguments() {
	return ["-d", "-l", "stdout", "-f", MAXSCALE_CONFIG_FILE];
}

function maxscaleLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: MAXSCALE_LOG_DIR + "/maxscale.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function maxscaleNode() {
	return {
		name: "maxscale",
		process: {
			binaryPath: "maxscale",
			arguments: maxscaleArguments(),
			user: "maxscale",
			group: "maxscale",
			log: maxscaleLog(),
		},
		readiness: {
			type: "tcp",
			tcp: { host: "127.0.0.1", port: parseInt(MAXSCALE_REST_PORT, 10) },
			interval: MAXSCALE_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: MAXSCALE_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startMaxScale() {
	chain.run({ nodes: [maxscaleNode()] });
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
	startMaxScale,
	startSleep,
	maxscaleNode,
	maxscaleArguments,
	maxscaleLog,
};
