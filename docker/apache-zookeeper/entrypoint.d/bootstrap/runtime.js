// runtime.js — supervise the ZooKeeper server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
//
// ZooKeeper is started through zkServer.sh start-foreground, which needs
// ZOOCFGDIR and ZOO_LOG_DIR; those are passed via the node's environment. The
// bash entrypoint exported JAVA_HOME and ZOOKEEPER_HOME, kept here too.
const { chain } = require("ezx");
const {
	ZOOKEEPER_CONFIG_DIR,
	ZOOKEEPER_LOG_DIR,
	ZOOKEEPER_USER,
	ZOOKEEPER_GROUP,
	ZOOKEEPER_CLIENT_PORT,
	ZOOKEEPER_READY_MAX_ATTEMPTS,
	ZOOKEEPER_READY_ATTEMPT_INTERVAL,
} = require("./env");

// zookeeperEnv — the environment zkServer.sh relies on.
function zookeeperEnv() {
	return [
		"JAVA_HOME=/opt/java",
		"ZOOKEEPER_HOME=/opt/zookeeper",
		"ZOOCFGDIR=" + ZOOKEEPER_CONFIG_DIR,
		"ZOO_LOG_DIR=" + ZOOKEEPER_LOG_DIR,
		"PATH=/opt/java/bin:/opt/zookeeper/bin:/usr/local/bin:/usr/bin:/bin",
	];
}

function zookeeperLog() {
	return {
		stdout: "file",
		stderr: "file",
		filePath: ZOOKEEPER_LOG_DIR + "/zookeeper.log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

function zookeeperNode() {
	return {
		name: "zookeeper",
		process: {
			binaryPath: "zkServer.sh",
			arguments: ["start-foreground"],
			user: ZOOKEEPER_USER,
			group: ZOOKEEPER_GROUP,
			environment: zookeeperEnv(),
			log: zookeeperLog(),
		},
		readiness: {
			type: "tcp",
			tcp: { host: "127.0.0.1", port: parseInt(ZOOKEEPER_CLIENT_PORT, 10) },
			interval: ZOOKEEPER_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: ZOOKEEPER_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function startZookeeper() {
	chain.run({ nodes: [zookeeperNode()] });
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
	startZookeeper,
	startSleep,
	zookeeperNode,
	zookeeperEnv,
	zookeeperLog,
};
