// env.js — Apache Flink environment configuration.
//
// Single source of truth for every environment-driven setting. The bash
// entrypoint generated flink-conf.yaml from every CONFIG_* environment variable
// (CONFIG_JOBMANAGER_RPC_ADDRESS -> jobmanager.rpc.address); that contract is
// preserved here: config.js enumerates CONFIG_* and writes the keys.
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const FLINK_DATA_DIR = env.get("FLINK_DATA_DIR", "/opt/containers/data");
const FLINK_CONFIG_DIR = env.get("FLINK_CONFIG_DIR", "/opt/containers/config");
const FLINK_LOG_DIR = env.get("FLINK_LOG_DIR", "/opt/containers/logs");
const FLINK_RUN_DIR = env.get("FLINK_RUN_DIR", "/opt/containers/run");
const FLINK_BACKUP_DIR = env.get("FLINK_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const FLINK_USER = env.get("FLINK_USER", "flink");
const FLINK_GROUP = env.get("FLINK_GROUP", "flink");

// ---------------------------------------------------------------------------
// Core (the CONFIG_* defaults exactly as the bash entrypoint declared them)
// ---------------------------------------------------------------------------
const CONFIG_JOBMANAGER_RPC_ADDRESS = env.get("CONFIG_JOBMANAGER_RPC_ADDRESS", "localhost");
const CONFIG_JOBMANAGER_RPC_PORT = env.get("CONFIG_JOBMANAGER_RPC_PORT", "6123");
const CONFIG_JOBMANAGER_MEMORY_PROCESS_SIZE = env.get("CONFIG_JOBMANAGER_MEMORY_PROCESS_SIZE", "1600m");
const CONFIG_TASKMANAGER_MEMORY_PROCESS_SIZE = env.get("CONFIG_TASKMANAGER_MEMORY_PROCESS_SIZE", "1728m");
const CONFIG_TASKMANAGER_NUMBER_OF_TASK_SLOTS = env.get("CONFIG_TASKMANAGER_NUMBER_OF_TASK_SLOTS", "1");
const CONFIG_PARALLELISM_DEFAULT = env.get("CONFIG_PARALLELISM_DEFAULT", "1");
const CONFIG_REST_ADDRESS = env.get("CONFIG_REST_ADDRESS", "0.0.0.0");
const CONFIG_REST_PORT = env.get("CONFIG_REST_PORT", "8081");
const CONFIG_STATE_BACKEND = env.get("CONFIG_STATE_BACKEND", "filesystem");
const CONFIG_STATE_CHECKPOINTS_DIR = env.get("CONFIG_STATE_CHECKPOINTS_DIR", "file:///opt/containers/data");
const CONFIG_STATE_SAVEPOINTS_DIR = env.get("CONFIG_STATE_SAVEPOINTS_DIR", "file:///opt/containers/data");
const CONFIG_LOG_FILE = env.get("CONFIG_LOG_FILE", "/opt/containers/logs/flink.log");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("FLINK_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const FLINK_READY_MAX_ATTEMPTS = env.int("FLINK_READY_MAX_ATTEMPTS", 30);
const FLINK_READY_ATTEMPT_INTERVAL = env.int("FLINK_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const FLINK_HOME = env.get("FLINK_HOME", "/opt/flink");
// flink-conf.yaml is generated in the config volume; the bash entrypoint used
// FLINK_CONF_DIR for exactly this.
const FLINK_CONF_FILE = FLINK_CONFIG_DIR + "/flink-conf.yaml";

module.exports = {
	FLINK_DATA_DIR,
	FLINK_CONFIG_DIR,
	FLINK_LOG_DIR,
	FLINK_RUN_DIR,
	FLINK_BACKUP_DIR,
	FLINK_USER,
	FLINK_GROUP,
	CONFIG_JOBMANAGER_RPC_ADDRESS,
	CONFIG_JOBMANAGER_RPC_PORT,
	CONFIG_JOBMANAGER_MEMORY_PROCESS_SIZE,
	CONFIG_TASKMANAGER_MEMORY_PROCESS_SIZE,
	CONFIG_TASKMANAGER_NUMBER_OF_TASK_SLOTS,
	CONFIG_PARALLELISM_DEFAULT,
	CONFIG_REST_ADDRESS,
	CONFIG_REST_PORT,
	CONFIG_STATE_BACKEND,
	CONFIG_STATE_CHECKPOINTS_DIR,
	CONFIG_STATE_SAVEPOINTS_DIR,
	CONFIG_LOG_FILE,
	SLEEP_MODE,
	FLINK_READY_MAX_ATTEMPTS,
	FLINK_READY_ATTEMPT_INTERVAL,
	FLINK_HOME,
	FLINK_CONF_FILE,
};
