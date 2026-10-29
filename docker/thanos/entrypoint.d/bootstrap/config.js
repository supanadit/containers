// config.js — declarative configuration generation for the Thanos container.
//
// Replaces the bash generate_s3_config heredoc with ezx.yaml, and returns
// FileProvision rules so the generated objstore/cache YAML is written through
// the same declarative path used by the other containers (mode 0600, owned by
// thanos). Because the secret lands in a 0600 file read with
// --objstore.config-file, it never appears in the process list or docker
// inspect.
const { yaml } = require("ezx");
const {
	THANOS_CONFIG_DIR,
	THANOS_USER,
	THANOS_GROUP,
	THANOS_OBJSTORE_FILE,
	THANOS_CACHE_CONFIG_FILE,
	THANOS_OBJSTORE_CONFIG,
	THANOS_OBJSTORE_CONFIG_FILE,
	THANOS_S3_BUCKET,
	THANOS_S3_ENDPOINT,
	THANOS_S3_ACCESS_KEY,
	THANOS_S3_SECRET_KEY,
	THANOS_S3_INSECURE,
	THANOS_S3_SIGNATURE_V2,
	THANOS_S3_CA_FILE,
	THANOS_S3_CERT_FILE,
	THANOS_S3_KEY_FILE,
	THANOS_S3_INSECURE_SKIP_VERIFY,
	THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG,
	s3Configured,
} = require("./env");

const OWNER = THANOS_USER + ":" + THANOS_GROUP;

// s3ObjstoreYaml — render the S3 objstore config (the bash generate_s3_config
// heredoc). Only keys the user actually set are emitted, so Thanos sees its own
// defaults for everything else.
function s3ObjstoreYaml() {
	const cfg = {
		bucket: THANOS_S3_BUCKET,
		endpoint: THANOS_S3_ENDPOINT,
		access_key: THANOS_S3_ACCESS_KEY,
		secret_key: THANOS_S3_SECRET_KEY,
		insecure: THANOS_S3_INSECURE,
		signature_version2: THANOS_S3_SIGNATURE_V2,
	};
	if (THANOS_S3_CA_FILE) cfg.ca_file = THANOS_S3_CA_FILE;
	if (THANOS_S3_CERT_FILE) cfg.cert_file = THANOS_S3_CERT_FILE;
	if (THANOS_S3_KEY_FILE) cfg.key_file = THANOS_S3_KEY_FILE;
	if (THANOS_S3_INSECURE_SKIP_VERIFY) cfg.insecure_skip_verify = true;
	return yaml.build({ type: "S3", config: cfg });
}

// configFiles — FileProvision rules for the generated configs. The objstore
// rule only exists when the S3 shorthand is complete; a mounted/inline
// objstore config is never overwritten.
function configFiles() {
	const rules = [];

	if (s3Configured()) {
		rules.push({
			path: THANOS_OBJSTORE_FILE,
			permission: 0o600,
			owner: OWNER,
			operations: [{ type: "replace", value: s3ObjstoreYaml() }],
		});
	}

	if (THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG) {
		rules.push({
			path: THANOS_CACHE_CONFIG_FILE,
			permission: 0o600,
			owner: OWNER,
			operations: [{ type: "replace", value: THANOS_QUERY_RANGE_RESPONSE_CACHE_CONFIG + "\n" }],
		});
	}

	return rules;
}

// objstoreArg — the flag pair pointing Thanos at its object store, in the same
// precedence order as the bash entrypoint: generated S3 file > inline config >
// mounted file. Returns null when nothing is configured.
function objstoreArg() {
	if (s3Configured()) {
		return { flag: "--objstore.config-file", value: THANOS_OBJSTORE_FILE };
	}
	if (THANOS_OBJSTORE_CONFIG) {
		return { flag: "--objstore.config", value: THANOS_OBJSTORE_CONFIG };
	}
	if (THANOS_OBJSTORE_CONFIG_FILE) {
		return { flag: "--objstore.config-file", value: THANOS_OBJSTORE_CONFIG_FILE };
	}
	return null;
}

module.exports = {
	configFiles,
	s3ObjstoreYaml,
	objstoreArg,
	OWNER,
};
