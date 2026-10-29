// config.js — generate config.yaml from CONFIG_* environment variables.
//
// The bash entrypoint looped over `compgen -v CONFIG_`, stripped the CONFIG_
// prefix, lowercased the name and replaced underscores with dots, then wrote
// `key: value` for each. This reproduces that contract exactly: any CONFIG_*
// variable in the environment becomes a flink-conf.yaml key. Keys are emitted
// sorted for deterministic output.
const { env, fs, config, log } = require("ezx");
const {
	FLINK_CONF_FILE,
	FLINK_CONFIG_DIR,
	FLINK_USER,
	FLINK_GROUP,
} = require("./env");

const OWNER = FLINK_USER + ":" + FLINK_GROUP;

// configPairs — [key, value] pairs from every CONFIG_* environment variable,
// with the documented name transform.
function configPairs() {
	const pairMap = {};
	const toKey = (name) =>
		name
			.replace(/^CONFIG_/, "")
			.toLowerCase()
			.replace(/_/g, ".");
	// The bash entrypoint exported its CONFIG_* defaults as shell variables, so
	// `compgen -v CONFIG_` saw them even when the user set nothing. env.all()
	// only sees the real environment, so seed from the declared defaults first —
	// without them the generated file is empty and Flink refuses to start
	// ("Either required fine-grained memory ... need to be configured").
	for (const [name, value] of Object.entries(require("./env"))) {
		if (!/^CONFIG_/.test(name)) continue;
		pairMap[toKey(name)] = String(value);
	}
	for (const name of Object.keys(env.all())) {
		if (!/^CONFIG_/.test(name)) continue;
		pairMap[toKey(name)] = String(env.all()[name]);
	}
	return Object.keys(pairMap)
		.sort()
		.map((k) => [k, pairMap[k]]);
}

// flinkConf — the generated config.yaml content from the CONFIG_* keys. Flink
// flattens YAML keys, so dotted keys are equivalent to the nested form.
// The bash entrypoint truncated the file and wrote only the CONFIG_* keys;
// that behaviour is preserved (a mounted/default config is not merged).
function flinkConf() {
	const b = config.builder({ separator: ": ", valueFormat: "none" });
	for (const [k, v] of configPairs()) b.set(k, v);
	return b.build();
}

// generateConfig — (re)write config.yaml in the config volume.
function generateConfig() {
	const content = flinkConf();
	try {
		fs.ensureDir(FLINK_CONFIG_DIR, { mode: 0o755 });
		fs.write(FLINK_CONF_FILE, content, { mode: 0o640 });
		fs.chown(FLINK_CONF_FILE, OWNER);
		fs.chmod(FLINK_CONF_FILE, 0o640);
	} catch (e) {
		throw new Error(
			"cannot write " + FLINK_CONF_FILE + " (" + e.message + "); mount the config path read-write",
		);
	}
	log.info("Generated " + FLINK_CONF_FILE + " from CONFIG_* environment variables");
}

module.exports = {
	generateConfig,
	flinkConf,
	configPairs,
	OWNER,
};
