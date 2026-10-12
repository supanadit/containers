// config.js — declarative config generation for the MariaDB container.
// Produces the z-mariadb-custom.cnf file via ezx FileProvision rules consumed
// by the database node (init/03-config in the original entrypoint).
const { env, fs, config } = require("ezx");
const {
	MARIADB_DATA_DIR,
	MARIADB_CONFIG_DIR,
	MARIADB_LOG_DIR,
	MARIADB_TIMEZONE,
	MARIADB_PORT,
	MARIADB_BIND_ADDRESS,
	MARIADB_WAIT_TIMEOUT,
	MARIADB_MAX_CONNECTIONS,
	MARIADB_MAX_ALLOWED_PACKET,
	MARIADB_KEY_BUFFER_SIZE,
	MARIADB_CHARACTER_SET_SERVER,
	MARIADB_COLLATION_SERVER,
	MARIADB_QUERY_CACHE_SIZE,
	MARIADB_QUERY_CACHE_LIMIT,
	MARIADB_SLOW_QUERY_LOG,
	MARIADB_LONG_QUERY_TIME,
	MARIADB_LOG_BIN,
	MARIADB_INNODB_BUFFER_POOL_SIZE,
	MARIADB_INNODB_LOG_FILE_SIZE,
	MARIADB_INNODB_FLUSH_METHOD,
	MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT,
	MARIADB_INNODB_FILE_PER_TABLE,
	MARIADB_EXPIRE_LOGS_DAYS,
	MARIADB_GALERA_ENABLE,
	MARIADB_GALERA_PROVIDER,
	MARIADB_GALERA_CLUSTER_NAME,
	MARIADB_GALERA_SEEDS,
	MARIADB_GALERA_SST_METHOD,
	MARIADB_GALERA_THREADS,
	MARIADB_GALERA_SERVER_ID,
	MARIADB_NODE_ADDRESS,
	MARIADB_SSL_ENABLE,
	MARIADB_SSL_CERT_DIR,
	MARIADB_CONFIG_FILE,
} = require("./env");

// mariadbConfig — build the z-mariadb-custom.cnf content declaratively.
// Mirrors the bash init/03-config.sh heredoc.
function mariadbConfig() {
	const b = config.builder({ separator: "=", valueFormat: "none" });

	const mysqld = b.section("mysqld");
	mysqld.set("datadir", MARIADB_DATA_DIR);
	mysqld.set("skip-name-resolve", "1");

	// Logging
	mysqld.set("log_error", MARIADB_LOG_DIR + "/error.log");
	mysqld.set("slow_query_log", MARIADB_SLOW_QUERY_LOG);
	mysqld.set("slow_query_log_file", MARIADB_LOG_DIR + "/slow-query.log");
	mysqld.set("long_query_time", MARIADB_LONG_QUERY_TIME);

	// Character set
	mysqld.set("character_set_server", MARIADB_CHARACTER_SET_SERVER);
	mysqld.set("collation_server", MARIADB_COLLATION_SERVER);

	// Connection settings
	mysqld.set("port", MARIADB_PORT);
	mysqld.set("bind-address", MARIADB_BIND_ADDRESS);
	mysqld.set("wait_timeout", MARIADB_WAIT_TIMEOUT);
	mysqld.set("max_connections", MARIADB_MAX_CONNECTIONS);
	mysqld.set("max_connect_errors", "100000");
	mysqld.set("max_allowed_packet", MARIADB_MAX_ALLOWED_PACKET);

	// Buffer settings
	mysqld.set("key_buffer_size", MARIADB_KEY_BUFFER_SIZE);
	mysqld.set("innodb_buffer_pool_size", MARIADB_INNODB_BUFFER_POOL_SIZE);
	mysqld.set("innodb_log_file_size", MARIADB_INNODB_LOG_FILE_SIZE);
	mysqld.set("innodb_flush_log_at_trx_commit", MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT);
	mysqld.set("innodb_flush_method", MARIADB_INNODB_FLUSH_METHOD);
	mysqld.set("innodb_file_per_table", MARIADB_INNODB_FILE_PER_TABLE);

	// Query cache — off by default, matching MariaDB upstream. The cache does
	// not scale on multi-core hosts and is a documented bottleneck under
	// high write throughput; a nonzero MARIADB_QUERY_CACHE_SIZE opts in.
	if (MARIADB_QUERY_CACHE_SIZE !== "0") {
		mysqld.set("query_cache_type", "1");
		mysqld.set("query_cache_size", MARIADB_QUERY_CACHE_SIZE);
		mysqld.set("query_cache_limit", MARIADB_QUERY_CACHE_LIMIT);
	}

	// Galera settings. Only emit the wsrep_* keys when Galera is enabled — a
	// bare wsrep_provider path makes mariadbd dlopen the library at startup and
	// abort if the file is absent.
	if (MARIADB_GALERA_ENABLE) {
		mysqld.set("wsrep_on", "1");
		mysqld.set("wsrep_provider", MARIADB_GALERA_PROVIDER);
		mysqld.set("wsrep_cluster_name", MARIADB_GALERA_CLUSTER_NAME);
		mysqld.set("wsrep_cluster_address", MARIADB_GALERA_SEEDS);
		mysqld.set("wsrep_sst_method", MARIADB_GALERA_SST_METHOD);
		mysqld.set("wsrep_slave_threads", MARIADB_GALERA_THREADS);
		mysqld.set("server_id", MARIADB_GALERA_SERVER_ID);
		if (MARIADB_NODE_ADDRESS) mysqld.set("wsrep_node_address", MARIADB_NODE_ADDRESS);
	}

	// Replication settings
	if (MARIADB_LOG_BIN && MARIADB_LOG_BIN !== "0") {
		mysqld.set("log_bin", MARIADB_LOG_DIR + "/mysql-bin");
		mysqld.set("binlog_format", "row");
		mysqld.set("sync_binlog", "1");
		mysqld.set("expire_logs_days", MARIADB_EXPIRE_LOGS_DAYS);
	}

	// SSL settings. Only emit the cert/key/ca paths when SSL is enabled:
	// MariaDB attempts SSL setup whenever ssl_cert/ssl_key are present, even
	// with ssl=0, and aborts if the files don't exist.
	mysqld.set("ssl", MARIADB_SSL_ENABLE ? "1" : "0");
	if (MARIADB_SSL_ENABLE) {
		mysqld.set("ssl_cert", MARIADB_SSL_CERT_DIR + "/server.crt");
		mysqld.set("ssl_key", MARIADB_SSL_CERT_DIR + "/server.key");
		mysqld.set("ssl_ca", MARIADB_SSL_CERT_DIR + "/ca.crt");
	}

	// Performance settings
	mysqld.set("innodb_io_capacity", "2000");
	mysqld.set("innodb_io_capacity_max", "4000");
	mysqld.set("innodb_read_io_threads", "8");
	mysqld.set("innodb_write_io_threads", "8");
	mysqld.set("innodb_thread_concurrency", "0");

	// Timezone
	mysqld.set("default_time_zone", MARIADB_TIMEZONE);

	// Temp tables
	mysqld.set("tmpdir", "/tmp");
	mysqld.set("max_heap_table_size", "256M");
	mysqld.set("tmp_table_size", "256M");

	// MARIADB_CONFIG_* overrides — apply LAST so they win over the hardcoded
	// defaults above. Enumerated from env so any mysqld key is settable without
	// a code change (mirrors PG_HBA_ADD_* pattern in postgresql config.js).
	for (const [k, v] of Object.entries(env.all()).sort(([a], [b]) => a.localeCompare(b))) {
		if (!/^MARIADB_CONFIG_(.+)$/.test(k)) continue;
		if (!v || String(v) === "") continue; // skip empty
		const key = k.replace(/^MARIADB_CONFIG_/, "").toLowerCase();
		mysqld.set(key, String(v));
	}

	// Client sections
	b.section("client").set("default-character-set", "utf8mb4");
	b.section("mysql").set("default-character-set", "utf8mb4");

	return b.build();
}

// mariadbFiles — declarative FileProvision rules consumed by the database node.
function mariadbFiles() {
	return [
		{
			path: MARIADB_CONFIG_FILE,
			permission: 0o644,
			owner: "mysql:mysql",
			operations: [{ type: "replace", value: mariadbConfig() }],
		},
	];
}

module.exports = { mariadbConfig, mariadbFiles };
