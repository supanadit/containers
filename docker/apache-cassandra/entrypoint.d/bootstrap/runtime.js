// runtime.js — supervise the Cassandra daemon. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
//
// The bash entrypoint was `exec cassandra -f` with JVM_OPTS exported. Here the
// foreground flag is passed explicitly and CASSANDRA_CONF / JAVA_HOME /
// JVM_OPTS are provided through the node environment.
const { chain } = require("ezx");
const {
	CASSANDRA_HOME,
	CASSANDRA_CONF,
	CASSANDRA_LOG_DIR,
	CASSANDRA_USER,
	CASSANDRA_GROUP,
	JVM_OPTS,
	CASSANDRA_NATIVE_PORT,
	CASSANDRA_EXTRA_ARGS,
	CASSANDRA_READY_MAX_ATTEMPTS,
	CASSANDRA_READY_ATTEMPT_INTERVAL,
} = require("./env");

// cassandraEnv — the environment the Cassandra launcher relies on.
function cassandraEnv() {
	return [
		"JAVA_HOME=/opt/java",
		"CASSANDRA_HOME=" + CASSANDRA_HOME,
		"CASSANDRA_CONF=" + CASSANDRA_CONF,
		"CASSANDRA_LOG_DIR=" + CASSANDRA_LOG_DIR,
		"JVM_OPTS=" + JVM_OPTS,
		"PATH=/opt/java/bin:/opt/cassandra/bin:/usr/local/bin:/usr/bin:/bin",
	];
}

// cassandraArguments — `-f` (foreground) plus any configured extra args.
function cassandraArguments() {
	const args = ["-f"];
	if (String(CASSANDRA_EXTRA_ARGS).trim() !== "") {
		for (const a of String(CASSANDRA_EXTRA_ARGS).trim().split(/\s+/)) args.push(a);
	}
	return args;
}

function cassandraLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: CASSANDRA_LOG_DIR + "/cassandra.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function cassandraNode() {
	return {
		name: "cassandra",
		process: {
			binaryPath: "cassandra",
			arguments: cassandraArguments(),
			user: CASSANDRA_USER,
			group: CASSANDRA_GROUP,
			environment: cassandraEnv(),
			log: cassandraLog(),
		},
		readiness: {
			type: "tcp",
			tcp: { host: "127.0.0.1", port: parseInt(CASSANDRA_NATIVE_PORT, 10) },
			interval: CASSANDRA_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: CASSANDRA_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 120e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startCassandra() {
	chain.run({ nodes: [cassandraNode()] });
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
	startCassandra,
	startSleep,
	cassandraNode,
	cassandraEnv,
	cassandraArguments,
	cassandraLog,
};
