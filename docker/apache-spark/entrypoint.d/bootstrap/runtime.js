// runtime.js — supervise the Spark standalone cluster (master + worker). ezx
// stays PID 1: it forwards signals, reaps zombies, rotates logs and probes
// readiness.
//
// The bash entrypoint backgrounded `start-master.sh`, slept 10s, backgrounded
// `start-worker.sh`, then tailed a log file to hold the container open. Both are
// now supervised nodes with a dependency edge: the worker starts once the
// master is ready, so ezx owns the whole tree and drains it on SIGTERM.
const { chain } = require("ezx");
const {
	SPARK_HOME,
	SPARK_CONFIG_DIR,
	SPARK_LOG_DIR,
	SPARK_USER,
	SPARK_GROUP,
	SPARK_MASTER_HOST,
	SPARK_MASTER_PORT,
	SPARK_MASTER_WEBUI_PORT,
	SPARK_MASTER_OPTS,
	SPARK_WORKER_OPTS,
	SPARK_READY_MAX_ATTEMPTS,
	SPARK_READY_ATTEMPT_INTERVAL,
	masterUrl,
} = require("./env");

// sparkEnv — JAVA_HOME/SPARK_HOME/PATH/SPARK_CONF_DIR, as the bash entrypoint
// exported them. The master URL and web UI port are passed through the
// launchers' own environment variables.
function sparkEnv() {
	return [
		"JAVA_HOME=/opt/java",
		"SPARK_HOME=" + SPARK_HOME,
		"SPARK_CONF_DIR=" + SPARK_CONFIG_DIR,
		"SPARK_MASTER_HOST=" + SPARK_MASTER_HOST,
		"SPARK_MASTER_PORT=" + SPARK_MASTER_PORT,
		"SPARK_MASTER_WEBUI_PORT=" + SPARK_MASTER_WEBUI_PORT,
		"SPARK_LOG_DIR=" + SPARK_LOG_DIR,
		"PATH=/opt/java/bin:/opt/spark/bin:/opt/spark/sbin:/usr/local/bin:/usr/bin:/bin",
	];
}

function sparkLog(name) {
	return {
		stdout: "file",
		stderr: "file",
		filePath: SPARK_LOG_DIR + "/" + name + ".log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// splitOpts — whitespace-split an OPTS string into extra arguments.
function splitOpts(v) {
	return String(v || "").trim() === "" ? [] : String(v).trim().split(/\s+/);
}

function masterNode() {
	const args = ["start-foreground"];
	for (const a of splitOpts(SPARK_MASTER_OPTS)) args.push(a);
	return {
		name: "spark-master",
		process: {
			binaryPath: "start-master.sh",
			arguments: args,
			user: SPARK_USER,
			group: SPARK_GROUP,
			environment: sparkEnv(),
			log: sparkLog("spark-master"),
		},
		readiness: {
			type: "http",
			http: { url: "http://127.0.0.1:" + SPARK_MASTER_WEBUI_PORT + "/", expectStatus: 200 },
			interval: SPARK_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: SPARK_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function workerNode() {
	const args = [masterUrl()];
	for (const a of splitOpts(SPARK_WORKER_OPTS)) args.push(a);
	return {
		name: "spark-worker",
		dependsOnEdges: [{ name: "spark-master", waitFor: "ready" }],
		process: {
			binaryPath: "start-worker.sh",
			arguments: args,
			user: SPARK_USER,
			group: SPARK_GROUP,
			environment: sparkEnv(),
			log: sparkLog("spark-worker"),
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function buildNodes() {
	return [masterNode(), workerNode()];
}

function startSpark() {
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
	startSpark,
	startSleep,
	buildNodes,
	masterNode,
	workerNode,
	sparkEnv,
	sparkLog,
	splitOpts,
};
