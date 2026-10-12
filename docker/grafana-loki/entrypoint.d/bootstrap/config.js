// config.js — declarative Loki YAML generation.
//
// Replaces the bash configuration.sh (heredoc-per-section) with one nested JS
// object serialized by ezx.yaml, so the output is deterministic (map keys are
// sorted) and there is no string concatenation. The bootstrap regenerates the
// config on every start, matching the original entrypoint: Loki is configured
// from environment variables, not from a mounted file.
const { fs, yaml, log } = require("ezx");
const {
	GRAFANA_LOKI_CONFIG,
	GRAFANA_LOKI_DATA_DIR,
	GRAFANA_LOKI_LISTEN_PORT_HTTP,
	GRAFANA_LOKI_LISTEN_PORT_GRPC,
	GRAFANA_LOKI_INSTANCE_ADDRESS,
	GRAFANA_LOKI_MEMBERLIST,
	GRAFANA_LOKI_COMPACTOR_ADDRESS,
	GRAFANA_LOKI_STORAGE_BACKEND,
	GRAFANA_LOKI_S3_BUCKET,
	GRAFANA_LOKI_S3_ENDPOINT,
	GRAFANA_LOKI_S3_ACCESS_KEY,
	GRAFANA_LOKI_S3_SECRET_KEY,
	GRAFANA_LOKI_S3_REGION,
	GRAFANA_LOKI_S3_FORCE_PATH_STYLE,
	GRAFANA_LOKI_S3_INSECURE,
	GRAFANA_LOKI_USER,
	GRAFANA_LOKI_GROUP,
} = require("./env");

const OWNER = GRAFANA_LOKI_USER + ":" + GRAFANA_LOKI_GROUP;

// memberlist — the memberlist block, or null when clustering is disabled.
function memberlistConfig() {
	if (!GRAFANA_LOKI_MEMBERLIST) return null;
	const joinMembers = String(GRAFANA_LOKI_MEMBERLIST)
		.split(",")
		.map((m) => m.trim())
		.filter(Boolean);
	return {
		join_members: joinMembers,
		dead_node_reclaim_time: "30s",
		gossip_to_dead_nodes_time: "15s",
		left_ingesters_timeout: "30s",
		bind_addr: ["0.0.0.0"],
		bind_port: 7946,
		gossip_interval: "2s",
	};
}

// commonStorage — filesystem or s3, matching GRAFANA_LOKI_STORAGE_BACKEND.
function commonStorage() {
	if (GRAFANA_LOKI_STORAGE_BACKEND === "s3") {
		return {
			s3: {
				bucketnames: GRAFANA_LOKI_S3_BUCKET,
				endpoint: GRAFANA_LOKI_S3_ENDPOINT,
				access_key_id: GRAFANA_LOKI_S3_ACCESS_KEY,
				secret_access_key: GRAFANA_LOKI_S3_SECRET_KEY,
				region: GRAFANA_LOKI_S3_REGION,
				s3forcepathstyle: GRAFANA_LOKI_S3_FORCE_PATH_STYLE === "true",
				insecure: GRAFANA_LOKI_S3_INSECURE === "true",
			},
		};
	}
	// filesystem (also the fallback for any unknown backend).
	return {
		filesystem: {
			chunks_directory: GRAFANA_LOKI_DATA_DIR + "/chunks",
			rules_directory: GRAFANA_LOKI_DATA_DIR + "/rules",
		},
	};
}

// commonBlock — the common: section with dynamic storage / ring / compactor.
function commonBlock() {
	const common = {
		path_prefix: GRAFANA_LOKI_DATA_DIR,
		replication_factor: 1,
		storage: commonStorage(),
		ring: { kvstore: { store: GRAFANA_LOKI_MEMBERLIST ? "memberlist" : "inmemory" } },
	};
	if (GRAFANA_LOKI_INSTANCE_ADDRESS) common.instance_address = GRAFANA_LOKI_INSTANCE_ADDRESS;
	if (GRAFANA_LOKI_COMPACTOR_ADDRESS) common.compactor_address = GRAFANA_LOKI_COMPACTOR_ADDRESS;
	return common;
}

// rulerBlock — ruler: section; the s3 ruler bucket only exists for s3.
function rulerBlock() {
	const ruler = { alertmanager_url: "http://localhost:9093" };
	if (GRAFANA_LOKI_STORAGE_BACKEND === "s3") {
		ruler.storage = { s3: { bucketnames: "loki-ruler" } };
	}
	return ruler;
}

// compactorBlock — compactor: section; retention/delete storage is filesystem
// only.
function compactorBlock() {
	const compactor = { working_directory: GRAFANA_LOKI_DATA_DIR + "/retention" };
	if (GRAFANA_LOKI_STORAGE_BACKEND === "filesystem") {
		compactor.delete_request_store = "filesystem";
		compactor.retention_enabled = true;
	}
	return compactor;
}

// lokiConfig — assemble the full Loki configuration document.
function lokiConfig() {
	const doc = {
		auth_enabled: false,
		server: {
			http_listen_address: "0.0.0.0",
			http_listen_port: parseInt(GRAFANA_LOKI_LISTEN_PORT_HTTP, 10),
			grpc_listen_port: parseInt(GRAFANA_LOKI_LISTEN_PORT_GRPC, 10),
		},
		common: commonBlock(),
		query_range: {
			results_cache: { cache: { embedded_cache: { enabled: true, max_size_mb: 100 } } },
		},
		limits_config: { metric_aggregation_enabled: true },
		schema_config: {
			configs: [
				{
					from: "2020-10-24",
					store: "tsdb",
					object_store: GRAFANA_LOKI_STORAGE_BACKEND,
					schema: "v13",
					index: { prefix: "index_", period: "24h" },
				},
			],
		},
		pattern_ingester: {
			enabled: true,
			metric_aggregation: { loki_address: "localhost:3100" },
		},
		ruler: rulerBlock(),
		frontend: { encoding: "protobuf" },
		compactor: compactorBlock(),
	};
	const ml = memberlistConfig();
	if (ml) doc.memberlist = ml;
	return yaml.build(doc);
}

// generateConfig — write the generated loki.yaml (owned by loki, mode 0640).
function generateConfig() {
	const content = lokiConfig();
	try {
		fs.write(GRAFANA_LOKI_CONFIG, content, { mode: 0o640 });
		fs.chown(GRAFANA_LOKI_CONFIG, OWNER);
		fs.chmod(GRAFANA_LOKI_CONFIG, 0o640);
	} catch (e) {
		throw new Error(
			"cannot write " + GRAFANA_LOKI_CONFIG + " (" + e.message + "); mount the config path read-write",
		);
	}
	log.info("Generated " + GRAFANA_LOKI_CONFIG);
}

module.exports = {
	generateConfig,
	lokiConfig,
	commonBlock,
	rulerBlock,
	compactorBlock,
	memberlistConfig,
	OWNER,
};
