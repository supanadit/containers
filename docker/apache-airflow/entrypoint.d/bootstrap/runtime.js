// runtime.js — supervise the Airflow API server. ezx stays PID 1: it forwards
// signals, reaps zombies, rotates the log and probes readiness.
//
// The bash entrypoint ran `airflow db migrate` once (when the sqlite DB was
// absent) then exec'd `airflow api-server`. The migration is a oneshot node so
// the API server starts only after the database is ready; both run inside one
// ezx graph.
const { fs, chain } = require("ezx");
const {
	AIRFLOW_DATA_DIR,
	AIRFLOW_HOME,
	AIRFLOW_LOG_DIR,
	AIRFLOW_USER,
	AIRFLOW_GROUP,
	AIRFLOW_PORT,
	AIRFLOW_HOST,
	AIRFLOW_CONFIG_FILE,
	AIRFLOW_DAGS_DIR,
	AIRFLOW_PLUGINS_DIR,
	AIRFLOW_SQLALCHEMY_CONN,
	AIRFLOW_READY_MAX_ATTEMPTS,
	AIRFLOW_READY_ATTEMPT_INTERVAL,
} = require("./env");

// airflowEnv — the environment Airflow relies on (home, paths, DB).
function airflowEnv() {
	return [
		"AIRFLOW_HOME=" + AIRFLOW_HOME,
		"AIRFLOW_CONFIG=" + AIRFLOW_CONFIG_FILE,
		"AIRFLOW__CORE__DAGS_FOLDER=" + AIRFLOW_DAGS_DIR,
		"AIRFLOW__CORE__BASE_LOG_FOLDER=" + AIRFLOW_LOG_DIR,
		"AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=" + AIRFLOW_SQLALCHEMY_CONN,
		"PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin",
	];
}

// dbFilePath — the sqlite file behind the sqlalchemy conn, or "" when the conn
// is not sqlite.
function dbFilePath() {
	const m = /^sqlite:\/\/\/(.+)$/.exec(AIRFLOW_SQLALCHEMY_CONN);
	return m ? m[1] : "";
}

function airflowLog(name) {
	return {
		stdout: "file",
		stderr: "file",
		filePath: AIRFLOW_LOG_DIR + "/" + name + ".log",
		maxBytes: 50 * 1024 * 1024,
		maxBackups: 5,
	};
}

// migrateNode — oneshot `airflow db migrate` (the bash `if [ ! -f airflow.db ]`).
function migrateNode() {
	return {
		name: "airflow-db-migrate",
		oneshot: true,
		optional: true,
		process: {
			binaryPath: "airflow",
			arguments: ["db", "migrate"],
			user: AIRFLOW_USER,
			group: AIRFLOW_GROUP,
			environment: airflowEnv(),
			log: airflowLog("airflow-migrate"),
		},
	};
}

// apiServerNode — the long-running API server.
function apiServerNode() {
	return {
		name: "airflow-api-server",
		dependsOnEdges: [{ name: "airflow-db-migrate", waitFor: "exit" }],
		process: {
			binaryPath: "airflow",
			arguments: ["api-server", "--port", AIRFLOW_PORT, "--host", AIRFLOW_HOST],
			user: AIRFLOW_USER,
			group: AIRFLOW_GROUP,
			environment: airflowEnv(),
			log: airflowLog("airflow-api-server"),
		},
		readiness: {
			// TCP on the API port is robust across Airflow 3 minor versions (the
			// exact health path changed between releases).
			type: "tcp",
			tcp: { host: "127.0.0.1", port: parseInt(AIRFLOW_PORT, 10) },
			interval: AIRFLOW_READY_ATTEMPT_INTERVAL * 1e9,
			timeout: 5e9,
			maxAttempts: AIRFLOW_READY_MAX_ATTEMPTS,
		},
		forwardSignals: ["SIGTERM", "SIGINT", "SIGHUP"],
		shutdown: { timeout: 60e9, forceKill: true },
		restart: { mode: "on-failure", maxRetries: 3, backoff: 2e9 },
	};
}

function buildNodes() {
	const nodes = [];
	// The migration only runs when the sqlite db is absent, mirroring the bash
	// guard. A non-sqlite connection is migrated by the operator.
	const db = dbFilePath();
	if (db === "" || !fs.exists(db)) nodes.push(migrateNode());
	nodes.push(apiServerNode());
	return nodes;
}

function startAirflow() {
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
	startAirflow,
	startSleep,
	buildNodes,
	apiServerNode,
	migrateNode,
	airflowEnv,
	dbFilePath,
	airflowLog,
};
