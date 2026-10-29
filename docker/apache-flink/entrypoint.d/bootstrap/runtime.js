// runtime.js — supervise the Flink standalone cluster (JobManager +
// TaskManager). ezx stays PID 1: it forwards signals, reaps zombies, rotates
// logs and probes readiness.
//
// The bash entrypoint backgrounded `taskmanager.sh start` and then exec'd
// `jobmanager.sh start-foreground`. Both are now supervised nodes with a
// dependency edge: the TaskManager starts once the JobManager has started, so
// ezx owns the whole tree and can drain it on SIGTERM.
const { chain } = require("ezx");
const {
	FLINK_HOME,
	FLINK_CONFIG_DIR,
	FLINK_LOG_DIR,
	FLINK_USER,
	FLINK_GROUP,
	CONFIG_REST_PORT,
	FLINK_READY_MAX_ATTEMPTS,
	FLINK_READY_ATTEMPT_INTERVAL,
} = require("./env");

// flinkEnv — JAVA_HOME/FLINK_HOME/PATH/FLINK_CONF_DIR, as the bash entrypoint
// exported them. FLINK_CONF_DIR points the launchers at the generated config.
function flinkEnv() {
	return [
		"JAVA_HOME=/opt/java",
		"FLINK_HOME=" + FLINK_HOME,
		"FLINK_CONF_DIR=" + FLINK_CONFIG_DIR,
		"PATH=/opt/java/bin:/opt/flink/bin:/usr/local/bin:/usr/bin:/bin",
	];
}

function flinkLog(name) {
	return {
		stdout: "file",
		stderr: "file",
		filePath: FLINK_LOG_DIR + "/" + name + ".log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// jobManagerNode — the long-running JobManager (start-foreground).
function jobManagerNode() {
	return {
		name: "jobmanager",
		process: {
			binaryPath: "jobmanager.sh",
			arguments: ["start-foreground"],
			user: FLINK_USER,
			group: FLINK_GROUP,
			environment: flinkEnv(),
			log: flinkLog("jobmanager"),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + CONFIG_REST_PORT + "/overview", expectStatus: 200 },
			interval: FLINK_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: FLINK_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

// taskManagerNode — the TaskManager, started once the JobManager has started.
function taskManagerNode() {
	return {
		name: "taskmanager",
		dependsOnEdges: [{ name: "jobmanager", waitFor: "started" }],
		process: {
			binaryPath: "taskmanager.sh",
			arguments: ["start-foreground"],
			user: FLINK_USER,
			group: FLINK_GROUP,
			environment: flinkEnv(),
			log: flinkLog("taskmanager"),
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function buildNodes() {
	return [jobManagerNode(), taskManagerNode()];
}

function startFlink() {
	chain.run({ nodes: buildNodes() });
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
	startFlink,
	startSleep,
	buildNodes,
	jobManagerNode,
	taskManagerNode,
	flinkEnv,
	flinkLog,
};
