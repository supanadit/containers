// env.js — Apache Kafka environment configuration.
//
// Single source of truth for every environment-driven setting. Every name
// exported here is consumed by at least one bootstrap module. Booleans use
// env.bool() so they arrive as real JS booleans (a "false" string is truthy
// and would silently enable a feature).
const { env } = require("ezx");

// ---------------------------------------------------------------------------
// Directories (volume-normalized under /opt/containers/<category>)
// ---------------------------------------------------------------------------
const KAFKA_DATA_DIR = env.get("KAFKA_DATA_DIR", "/opt/containers/data");
const KAFKA_LOG_DIR = env.get("KAFKA_LOG_DIR", "/opt/containers/logs");
const KAFKA_RUN_DIR = env.get("KAFKA_RUN_DIR", "/opt/containers/run");
const KAFKA_CONFIG_DIR = env.get("KAFKA_CONFIG_DIR", "/opt/containers/config");
const KAFKA_BACKUP_DIR = env.get("KAFKA_BACKUP_DIR", "/opt/containers/backup");

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------
const KAFKA_USER = env.get("KAFKA_USER", "kafka");
const KAFKA_GROUP = env.get("KAFKA_GROUP", "kafka");

// ---------------------------------------------------------------------------
// Core / KRaft
// ---------------------------------------------------------------------------
const KAFKA_VERSION = env.get("KAFKA_VERSION", "3.9.2");
const KAFKA_NODE_ID = env.get("KAFKA_NODE_ID", "1");
const KAFKA_PROCESS_ROLES = env.get("KAFKA_PROCESS_ROLES", "broker,controller");
const KAFKA_CONTROLLER_QUORUM_VOTERS = env.get(
	"KAFKA_CONTROLLER_QUORUM_VOTERS",
	"1@localhost:9093",
);
const KAFKA_CONTROLLER_LISTENER_NAMES = env.get("KAFKA_CONTROLLER_LISTENER_NAMES", "CONTROLLER");
const KAFKA_LISTENERS = env.get("KAFKA_LISTENERS", "PLAINTEXT://:9092,CONTROLLER://:9093");
const KAFKA_INTER_BROKER_LISTENER_NAME = env.get("KAFKA_INTER_BROKER_LISTENER_NAME", "PLAINTEXT");
const KAFKA_ADVERTISED_LISTENERS = env.get("KAFKA_ADVERTISED_LISTENERS", "PLAINTEXT://localhost:9092");
const KAFKA_LISTENER_SECURITY_PROTOCOL_MAP = env.get(
	"KAFKA_LISTENER_SECURITY_PROTOCOL_MAP",
	"CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL",
);
const KAFKA_CLUSTER_ID = env.get("KAFKA_CLUSTER_ID", "");

// ---------------------------------------------------------------------------
// Performance / storage
// ---------------------------------------------------------------------------
const KAFKA_NUM_NETWORK_THREADS = env.get("KAFKA_NUM_NETWORK_THREADS", "3");
const KAFKA_NUM_IO_THREADS = env.get("KAFKA_NUM_IO_THREADS", "8");
const KAFKA_SOCKET_SEND_BUFFER_BYTES = env.get("KAFKA_SOCKET_SEND_BUFFER_BYTES", "102400");
const KAFKA_SOCKET_RECEIVE_BUFFER_BYTES = env.get("KAFKA_SOCKET_RECEIVE_BUFFER_BYTES", "102400");
const KAFKA_SOCKET_REQUEST_MAX_BYTES = env.get("KAFKA_SOCKET_REQUEST_MAX_BYTES", "104857600");
const KAFKA_NUM_PARTITIONS = env.get("KAFKA_NUM_PARTITIONS", "1");
const KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR = env.get(
	"KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR",
	"1",
);
const KAFKA_LOG_DIRS = env.get("KAFKA_LOG_DIRS", KAFKA_DATA_DIR);
const KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR = env.get("KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", "1");
const KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR = env.get(
	"KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR",
	"1",
);
const KAFKA_TRANSACTION_STATE_LOG_MIN_ISR = env.get("KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", "1");
const KAFKA_LOG_RETENTION_HOURS = env.get("KAFKA_LOG_RETENTION_HOURS", "168");
const KAFKA_LOG_SEGMENT_BYTES = env.get("KAFKA_LOG_SEGMENT_BYTES", "1073741824");
const KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS = env.get("KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS", "300000");
const KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS = env.get("KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", "0");
const KAFKA_MESSAGE_MAX_BYTES = env.get("KAFKA_MESSAGE_MAX_BYTES", "1048588");
const KAFKA_REPLICA_FETCH_MAX_BYTES = env.get("KAFKA_REPLICA_FETCH_MAX_BYTES", "1048576");
const KAFKA_MAX_CONNECTIONS_PER_IP = env.get("KAFKA_MAX_CONNECTIONS_PER_IP", "2147483647");
const KAFKA_MAX_CONNECTION_CREATION_RATE = env.get("KAFKA_MAX_CONNECTION_CREATION_RATE", "2147483647");
const KAFKA_AUTO_CREATE_TOPICS_ENABLE = env.get("KAFKA_AUTO_CREATE_TOPICS_ENABLE", "true");
const KAFKA_DELETE_TOPIC_ENABLE = env.get("KAFKA_DELETE_TOPIC_ENABLE", "true");

// ---------------------------------------------------------------------------
// JVM
// ---------------------------------------------------------------------------
const KAFKA_HEAP_OPTS = env.get("KAFKA_HEAP_OPTS", "");
const KAFKA_JVM_PERFORMANCE_OPTS = env.get("KAFKA_JVM_PERFORMANCE_OPTS", "");

// ---------------------------------------------------------------------------
// TLS (applies to every SSL / SASL_SSL listener unless a listener override is
// provided). PKCS12/JKS via keystore/truststore, or PEM via the PEM keys.
// ---------------------------------------------------------------------------
const KAFKA_SSL_ENABLE = env.bool("KAFKA_SSL_ENABLE");
const KAFKA_SSL_KEYSTORE_TYPE = env.get("KAFKA_SSL_KEYSTORE_TYPE", "PKCS12");
const KAFKA_SSL_KEYSTORE_LOCATION = env.get("KAFKA_SSL_KEYSTORE_LOCATION", "");
const KAFKA_SSL_KEYSTORE_PASSWORD = env.get("KAFKA_SSL_KEYSTORE_PASSWORD", "");
const KAFKA_SSL_KEY_PASSWORD = env.get("KAFKA_SSL_KEY_PASSWORD", "");
const KAFKA_SSL_TRUSTSTORE_TYPE = env.get("KAFKA_SSL_TRUSTSTORE_TYPE", "PKCS12");
const KAFKA_SSL_TRUSTSTORE_LOCATION = env.get("KAFKA_SSL_TRUSTSTORE_LOCATION", "");
const KAFKA_SSL_TRUSTSTORE_PASSWORD = env.get("KAFKA_SSL_TRUSTSTORE_PASSWORD", "");
const KAFKA_SSL_CLIENT_AUTH = env.get("KAFKA_SSL_CLIENT_AUTH", "none");
const KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM = env.get(
	"KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM",
	"HTTPS",
);
const KAFKA_SSL_PROTOCOL = env.get("KAFKA_SSL_PROTOCOL", "TLSv1.3");
const KAFKA_SSL_ENABLED_PROTOCOLS = env.get("KAFKA_SSL_ENABLED_PROTOCOLS", "TLSv1.3,TLSv1.2");
const KAFKA_SSL_CIPHER_SUITES = env.get("KAFKA_SSL_CIPHER_SUITES", "");
// PEM mode (KAFKA_SSL_KEYSTORE_TYPE=PEM): inline key + certificate chain.
const KAFKA_SSL_KEYSTORE_KEY = env.get("KAFKA_SSL_KEYSTORE_KEY", "");
const KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN = env.get("KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN", "");
const KAFKA_SSL_TRUSTSTORE_CERTIFICATES = env.get("KAFKA_SSL_TRUSTSTORE_CERTIFICATES", "");

// ---------------------------------------------------------------------------
// SASL
// ---------------------------------------------------------------------------
const KAFKA_SASL_ENABLED_MECHANISMS = env.get("KAFKA_SASL_ENABLED_MECHANISMS", "PLAIN");
const KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL = env.get(
	"KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL",
	"PLAIN",
);
// Global JAAS config applied to every SASL listener unless a per-listener
// override is supplied via KAFKA_SASL_JAAS_CONFIG_<LISTENER_NAME>.
const KAFKA_SASL_JAAS_CONFIG = env.get("KAFKA_SASL_JAAS_CONFIG", "");
// Optional SCRAM credential bootstrap: "user:pass[,user:pass...]". Applied via
// kafka-configs.sh after the broker is ready.
const KAFKA_SASL_SCRAM_USERS = env.get("KAFKA_SASL_SCRAM_USERS", "");

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
const LOG_LEVEL = env.get("LOG_LEVEL", "INFO");
const KAFKA_LOG4J_ROOT_LOGLEVEL = env.get("KAFKA_LOG4J_ROOT_LOGLEVEL", LOG_LEVEL);
const KAFKA_LOG4J_LOGGERS = env.get("KAFKA_LOG4J_LOGGERS", "");

// ---------------------------------------------------------------------------
// Scheduling (optional KRaft metadata snapshot)
// ---------------------------------------------------------------------------
const KAFKA_METADATA_BACKUP_ENABLE = env.bool("KAFKA_METADATA_BACKUP_ENABLE");
const KAFKA_METADATA_BACKUP_SCHEDULE = env.get("KAFKA_METADATA_BACKUP_SCHEDULE", "0 3 * * *");
const KAFKA_METADATA_BACKUP_TIMEZONE = env.get("KAFKA_METADATA_BACKUP_TIMEZONE", "UTC");
const KAFKA_METADATA_BACKUP_RETENTION_DAYS = env.get("KAFKA_METADATA_BACKUP_RETENTION_DAYS", "7");

// ---------------------------------------------------------------------------
// Testing / debugging
// ---------------------------------------------------------------------------
// SLEEP_MODE is the cross-container convention; KAFKA_SLEEP_MODE is kept as a
// backwards-compatible alias for existing deployments.
const SLEEP_MODE = env.bool("SLEEP_MODE", false) || env.bool("KAFKA_SLEEP_MODE", false);

// ---------------------------------------------------------------------------
// Readiness probe
// ---------------------------------------------------------------------------
const KAFKA_READY_MAX_ATTEMPTS = env.int("KAFKA_READY_MAX_ATTEMPTS", 30);
const KAFKA_READY_ATTEMPT_INTERVAL = env.int("KAFKA_READY_ATTEMPT_INTERVAL", 1);

// ---------------------------------------------------------------------------
// Derived paths
// ---------------------------------------------------------------------------
const KAFKA_SERVER_PROPERTIES = KAFKA_CONFIG_DIR + "/server.properties";
const KAFKA_SERVER_PROPERTIES_ORIGINAL = KAFKA_CONFIG_DIR + "/server.properties.original";
const KAFKA_SERVER_PROPERTIES_USER = KAFKA_CONFIG_DIR + "/server.properties.user";
const KAFKA_CONFIG_MARKER = KAFKA_CONFIG_DIR + "/.server.properties.generated";
const KAFKA_JAAS_FILE = KAFKA_CONFIG_DIR + "/kafka_jaas.conf";
const KAFKA_CLUSTER_ID_FILE = KAFKA_DATA_DIR + "/cluster.id";
const KAFKA_META_PROPERTIES = KAFKA_DATA_DIR + "/meta.properties";

// Kafka 4.x moved to log4j2 (log4j2.configurationFile + log4j2 config format);
// 3.9.x still uses log4j 1.x (log4j.configuration). Pick the filename and the
// system property accordingly so KAFKA_LOG4J_OPTS is valid on both.
const KAFKA_VERSION_MAJOR = parseInt(String(KAFKA_VERSION).split(".")[0], 10);
const KAFKA_LOG4J2 = KAFKA_VERSION_MAJOR >= 4;
const KAFKA_LOG4J_FILE = KAFKA_LOG4J2
	? KAFKA_CONFIG_DIR + "/log4j2.properties"
	: KAFKA_CONFIG_DIR + "/log4j.properties";

module.exports = {
	// directories
	KAFKA_DATA_DIR,
	KAFKA_LOG_DIR,
	KAFKA_RUN_DIR,
	KAFKA_CONFIG_DIR,
	KAFKA_BACKUP_DIR,
	// identity
	KAFKA_USER,
	KAFKA_GROUP,
	// core / kraft
	KAFKA_VERSION,
	KAFKA_NODE_ID,
	KAFKA_PROCESS_ROLES,
	KAFKA_CONTROLLER_QUORUM_VOTERS,
	KAFKA_CONTROLLER_LISTENER_NAMES,
	KAFKA_LISTENERS,
	KAFKA_INTER_BROKER_LISTENER_NAME,
	KAFKA_ADVERTISED_LISTENERS,
	KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
	KAFKA_CLUSTER_ID,
	// performance / storage
	KAFKA_NUM_NETWORK_THREADS,
	KAFKA_NUM_IO_THREADS,
	KAFKA_SOCKET_SEND_BUFFER_BYTES,
	KAFKA_SOCKET_RECEIVE_BUFFER_BYTES,
	KAFKA_SOCKET_REQUEST_MAX_BYTES,
	KAFKA_NUM_PARTITIONS,
	KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR,
	KAFKA_LOG_DIRS,
	KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR,
	KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR,
	KAFKA_TRANSACTION_STATE_LOG_MIN_ISR,
	KAFKA_LOG_RETENTION_HOURS,
	KAFKA_LOG_SEGMENT_BYTES,
	KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS,
	KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS,
	KAFKA_MESSAGE_MAX_BYTES,
	KAFKA_REPLICA_FETCH_MAX_BYTES,
	KAFKA_MAX_CONNECTIONS_PER_IP,
	KAFKA_MAX_CONNECTION_CREATION_RATE,
	KAFKA_AUTO_CREATE_TOPICS_ENABLE,
	KAFKA_DELETE_TOPIC_ENABLE,
	// jvm
	KAFKA_HEAP_OPTS,
	KAFKA_JVM_PERFORMANCE_OPTS,
	// tls
	KAFKA_SSL_ENABLE,
	KAFKA_SSL_KEYSTORE_TYPE,
	KAFKA_SSL_KEYSTORE_LOCATION,
	KAFKA_SSL_KEYSTORE_PASSWORD,
	KAFKA_SSL_KEY_PASSWORD,
	KAFKA_SSL_TRUSTSTORE_TYPE,
	KAFKA_SSL_TRUSTSTORE_LOCATION,
	KAFKA_SSL_TRUSTSTORE_PASSWORD,
	KAFKA_SSL_CLIENT_AUTH,
	KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM,
	KAFKA_SSL_PROTOCOL,
	KAFKA_SSL_ENABLED_PROTOCOLS,
	KAFKA_SSL_CIPHER_SUITES,
	KAFKA_SSL_KEYSTORE_KEY,
	KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN,
	KAFKA_SSL_TRUSTSTORE_CERTIFICATES,
	// sasl
	KAFKA_SASL_ENABLED_MECHANISMS,
	KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL,
	KAFKA_SASL_JAAS_CONFIG,
	KAFKA_SASL_SCRAM_USERS,
	// logging
	LOG_LEVEL,
	KAFKA_LOG4J_ROOT_LOGLEVEL,
	KAFKA_LOG4J_LOGGERS,
	// scheduling
	KAFKA_METADATA_BACKUP_ENABLE,
	KAFKA_METADATA_BACKUP_SCHEDULE,
	KAFKA_METADATA_BACKUP_TIMEZONE,
	KAFKA_METADATA_BACKUP_RETENTION_DAYS,
	// misc
	SLEEP_MODE,
	// readiness
	KAFKA_READY_MAX_ATTEMPTS,
	KAFKA_READY_ATTEMPT_INTERVAL,
	// derived paths
	KAFKA_SERVER_PROPERTIES,
	KAFKA_SERVER_PROPERTIES_ORIGINAL,
	KAFKA_SERVER_PROPERTIES_USER,
	KAFKA_CONFIG_MARKER,
	KAFKA_JAAS_FILE,
	KAFKA_CLUSTER_ID_FILE,
	KAFKA_META_PROPERTIES,
	KAFKA_VERSION_MAJOR,
	KAFKA_LOG4J2,
	KAFKA_LOG4J_FILE,
};
