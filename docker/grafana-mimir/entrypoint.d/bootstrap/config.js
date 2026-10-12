// config.js — declarative Mimir YAML generation.
//
// Replaces the bash configuration.sh with one nested JS object serialized by
// ezx.yaml. The bash original generated to a hardcoded /etc/mimir.yaml while
// the entrypoint passed --config.file=${GRAFANA_MIMIR_CONFIG}
// (/opt/containers/config/mimir.yaml), so the flag pointed at a file that was
// never written. The generated file now lands at GRAFANA_MIMIR_CONFIG.
const { fs, yaml, log } = require("ezx");
const {
	GRAFANA_MIMIR_CONFIG,
	MIMIR_TARGET,
	MIMIR_STORAGE_PREFIX,
	MIMIR_TSDB_DIR,
	MIMIR_MEMBER_LIST,
	MIMIR_INGESTER_REPLICATION_FACTOR,
	GRAFANA_MIMIR_USER,
	GRAFANA_MIMIR_GROUP,
} = require("./env");

const OWNER = GRAFANA_MIMIR_USER + ":" + GRAFANA_MIMIR_GROUP;

// memberlist — join_members split from the comma-separated env var, or null
// when clustering is disabled.
function memberlist() {
	if (!MIMIR_MEMBER_LIST) return null;
	return {
		join_members: String(MIMIR_MEMBER_LIST)
			.split(",")
			.map((m) => m.trim())
			.filter(Boolean),
	};
}

// mimirConfig — assemble the Mimir configuration document.
function mimirConfig() {
	const doc = {
		target: MIMIR_TARGET,
		blocks_storage: {
			storage_prefix: MIMIR_STORAGE_PREFIX,
			tsdb: { dir: MIMIR_TSDB_DIR },
		},
		ingester: {
			ring: { replication_factor: MIMIR_INGESTER_REPLICATION_FACTOR },
		},
	};
	const ml = memberlist();
	if (ml) doc.memberlist = ml;
	return yaml.build(doc);
}

// generateConfig — write the generated mimir.yaml (owned by mimir, mode 0640).
function generateConfig() {
	const content = mimirConfig();
	try {
		fs.write(GRAFANA_MIMIR_CONFIG, content, { mode: 0o640 });
		fs.chown(GRAFANA_MIMIR_CONFIG, OWNER);
		fs.chmod(GRAFANA_MIMIR_CONFIG, 0o640);
	} catch (e) {
		throw new Error(
			"cannot write " + GRAFANA_MIMIR_CONFIG + " (" + e.message + "); mount the config path read-write",
		);
	}
	log.info("Generated " + GRAFANA_MIMIR_CONFIG);
}

module.exports = {
	generateConfig,
	mimirConfig,
	memberlist,
	OWNER,
};
