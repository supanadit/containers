// config.js — declarative Tempo YAML generation.
//
// Replaces the bash configuration.sh (heredoc-per-section) with one nested JS
// object serialized by ezx.yaml. The dynamic parts are preserved exactly:
// external labels come from EXTERNAL_LABELS_* env vars, remote_write targets
// from REMOTE_WRITE_<n>_URL / REMOTE_WRITE_<n>_SEND_EXEMPLARS (sorted
// numerically), and the querier worker address defaults to the container IP.
const { env, fs, process, yaml, log } = require("ezx");
const {
	GRAFANA_TEMPO_CONFIG,
	GRAFANA_TEMPO_DATA_DIR,
	GRAFANA_TEMPO_LISTEN_PORT_HTTP,
	GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER,
	GRAFANA_TEMPO_STORAGE_BACKEND,
	GRAFANA_TEMPO_S3_BUCKET,
	GRAFANA_TEMPO_S3_ENDPOINT,
	GRAFANA_TEMPO_S3_ACCESS_KEY,
	GRAFANA_TEMPO_S3_SECRET_KEY,
	GRAFANA_TEMPO_S3_INSECURE,
	GRAFANA_TEMPO_S3_REGION,
	STREAM_OVER_HTTP_ENABLED,
	ENABLE_OVERRIDE_DEFAULT_METRICS_GENERATOR,
	OVERRIDE_DEFAULT_METRICS_GENERATOR_PROCESSORS,
	ENABLE_GENERATIVE_HISTOGRAMS,
	GENERATE_NATIVE_HISTOGRAMS,
	ENABLE_MEMBERLIST,
	MEMBERLIST_BIND_PORT,
	MEMBERLIST_ABORT_IF_CLUSTER_JOIN_FAILS,
	MEMBERLIST_JOIN_MEMBERS,
	GRAFANA_TEMPO_USER,
	GRAFANA_TEMPO_GROUP,
} = require("./env");

const OWNER = GRAFANA_TEMPO_USER + ":" + GRAFANA_TEMPO_GROUP;

// externalLabels — EXTERNAL_LABELS_<KEY> env vars, lowercased, or the two
// built-in defaults when none are set (matching the bash fallback).
function externalLabels() {
	const all = env.all();
	const keys = Object.keys(all)
		.filter((k) => k.startsWith("EXTERNAL_LABELS_"))
		.sort();
	if (keys.length === 0) {
		return { source: "tempo", cluster: "demo" };
	}
	const out = {};
	for (const k of keys) {
		out[k.replace(/^EXTERNAL_LABELS_/, "").toLowerCase()] = all[k];
	}
	return out;
}

// remoteWriteTargets — REMOTE_WRITE_<n>_URL env vars with optional
// REMOTE_WRITE_<n>_SEND_EXEMPLARS, ordered by numeric suffix.
function remoteWriteTargets() {
	const all = env.all();
	const nums = [];
	for (const k of Object.keys(all)) {
		const m = /^REMOTE_WRITE_([0-9]+)_URL$/.exec(k);
		if (m) nums.push(parseInt(m[1], 10));
	}
	nums.sort((a, b) => a - b);
	const out = [];
	for (const n of nums) {
		const entry = { url: all["REMOTE_WRITE_" + n + "_URL"] };
		const send = all["REMOTE_WRITE_" + n + "_SEND_EXEMPLARS"];
		if (send) entry.send_exemplars = send === "true" || send === "True" || send === "1";
		out.push(entry);
	}
	return out;
}

// workerAddress — the configured frontend worker address, or the container's
// own IP:9095. The bash original resolved the IP with `hostname -i`; ezx has
// no IP-of-interface helper, so the same command is run through process.capture
// (and 127.0.0.1 is the fallback when the lookup fails).
function workerAddress() {
	if (GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER) return GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER;
	let ip = "";
	try {
		const res = process.capture({
			name: "hostname-i",
			process: { binaryPath: "hostname", arguments: ["-i"] },
		});
		// `hostname -i` can report several addresses; take the first token.
		ip = String(res.stdout || "").trim().split(/\s+/)[0];
	} catch (e) {
		ip = "";
	}
	return (ip || "127.0.0.1") + ":9095";
}

// traceStorage — the trace backend block (local or s3).
function traceStorage() {
	const trace = {
		backend: GRAFANA_TEMPO_STORAGE_BACKEND,
		wal: { path: GRAFANA_TEMPO_DATA_DIR + "/wal" },
	};
	if (GRAFANA_TEMPO_STORAGE_BACKEND === "local") {
		trace.local = { path: GRAFANA_TEMPO_DATA_DIR + "/blocks" };
	}
	if (GRAFANA_TEMPO_STORAGE_BACKEND === "s3") {
		const s3 = {
			bucket: GRAFANA_TEMPO_S3_BUCKET,
			endpoint: GRAFANA_TEMPO_S3_ENDPOINT,
			access_key: GRAFANA_TEMPO_S3_ACCESS_KEY,
			secret_key: GRAFANA_TEMPO_S3_SECRET_KEY,
			insecure: GRAFANA_TEMPO_S3_INSECURE === "true",
		};
		if (GRAFANA_TEMPO_S3_REGION) s3.region = GRAFANA_TEMPO_S3_REGION;
		trace.s3 = s3;
	}
	return trace;
}

// metricsGenerator — registry labels + local generators storage when local.
function metricsGenerator() {
	const generator = { registry: { external_labels: externalLabels() } };
	if (GRAFANA_TEMPO_STORAGE_BACKEND === "local") {
		const storage = { path: GRAFANA_TEMPO_DATA_DIR + "/generators/wal" };
		const rw = remoteWriteTargets();
		if (rw.length > 0) storage.remote_write = rw;
		generator.storage = storage;
	}
	generator.traces_storage = { path: GRAFANA_TEMPO_DATA_DIR + "/generators/traces" };
	return generator;
}

// overrides — defaults.metrics_generator, only when enabled.
function overrides() {
	if (!ENABLE_OVERRIDE_DEFAULT_METRICS_GENERATOR) return null;
	const processors = String(OVERRIDE_DEFAULT_METRICS_GENERATOR_PROCESSORS)
		.split(",")
		.map((p) => p.trim())
		.filter(Boolean);
	const mg = { processors };
	if (ENABLE_GENERATIVE_HISTOGRAMS) {
		mg.generate_native_histograms = GENERATE_NATIVE_HISTOGRAMS;
	}
	return { defaults: { metrics_generator: mg } };
}

// memberlist — join_members split from the comma-separated env var.
function memberlist() {
	if (!ENABLE_MEMBERLIST) return null;
	const members = String(MEMBERLIST_JOIN_MEMBERS)
		.split(",")
		.map((m) => m.trim())
		.filter(Boolean);
	return {
		abort_if_cluster_join_fails: MEMBERLIST_ABORT_IF_CLUSTER_JOIN_FAILS === "true",
		bind_port: parseInt(MEMBERLIST_BIND_PORT, 10),
		join_members: members,
	};
}

// tempoConfig — assemble the full Tempo configuration document.
function tempoConfig() {
	const doc = {
		server: {
			http_listen_port: parseInt(GRAFANA_TEMPO_LISTEN_PORT_HTTP, 10),
		},
		storage: { trace: traceStorage() },
		metrics_generator: metricsGenerator(),
		querier: { frontend_worker: { frontend_address: workerAddress() } },
	};
	if (STREAM_OVER_HTTP_ENABLED) {
		doc.stream_over_http_enabled = STREAM_OVER_HTTP_ENABLED === "true";
	}
	const ov = overrides();
	if (ov) doc.overrides = ov;
	const ml = memberlist();
	if (ml) doc.memberlist = ml;
	return yaml.build(doc);
}

// generateConfig — write the generated tempo.yaml (owned by tempo, mode 0640).
function generateConfig() {
	const content = tempoConfig();
	try {
		fs.write(GRAFANA_TEMPO_CONFIG, content, { mode: 0o640 });
		fs.chown(GRAFANA_TEMPO_CONFIG, OWNER);
		fs.chmod(GRAFANA_TEMPO_CONFIG, 0o640);
	} catch (e) {
		throw new Error(
			"cannot write " + GRAFANA_TEMPO_CONFIG + " (" + e.message + "); mount the config path read-write",
		);
	}
	log.info("Generated " + GRAFANA_TEMPO_CONFIG);
}

module.exports = {
	generateConfig,
	tempoConfig,
	traceStorage,
	metricsGenerator,
	overrides,
	memberlist,
	externalLabels,
	remoteWriteTargets,
	workerAddress,
	OWNER,
};
