// util.js — shared helpers for listener parsing and security-protocol
// classification. Used by both config.js (generation) and validation.js
// (cross-field checks) so the two never disagree.

// parseListeners — parse KAFKA_LISTENERS
// ("NAME://host:port,NAME://:port") into [{name, url, host, port}].
function parseListeners(spec) {
	const out = [];
	for (const raw of String(spec || "").split(",")) {
		const entry = raw.trim();
		if (entry === "") continue;
		const m = /^([A-Za-z0-9_-]+):\/\/(.*)$/.exec(entry);
		if (!m) {
			out.push({ name: entry, url: entry, host: "", port: "", valid: false });
			continue;
		}
		const name = m[1];
		const addr = m[2];
		// host:port — host may be empty (bind all).
		const idx = addr.lastIndexOf(":");
		const host = idx >= 0 ? addr.slice(0, idx) : addr;
		const port = idx >= 0 ? addr.slice(idx + 1) : "";
		out.push({ name: name, url: entry, host: host, port: port, valid: /^[0-9]+$/.test(port) });
	}
	return out;
}

// parseSecurityMap — parse KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
// ("NAME:PROTOCOL,...") into a lowercased name -> uppercase protocol map.
function parseSecurityMap(spec) {
	const out = {};
	for (const raw of String(spec || "").split(",")) {
		const entry = raw.trim();
		if (entry === "") continue;
		const idx = entry.indexOf(":");
		if (idx < 0) continue;
		const name = entry.slice(0, idx).trim();
		const proto = entry.slice(idx + 1).trim().toUpperCase();
		if (name !== "") out[name.toLowerCase()] = proto;
	}
	return out;
}

// listenerProtocol — protocol for a listener object/name, or "" when unmapped.
function listenerProtocol(listener, securityMap) {
	const name = typeof listener === "string" ? listener : listener.name;
	return securityMap[String(name).toLowerCase()] || "";
}

// protocolRequiresTls / protocolRequiresSasl — classify a Kafka security
// protocol.
function protocolRequiresTls(proto) {
	return proto === "SSL" || proto === "SASL_SSL";
}

function protocolRequiresSasl(proto) {
	return proto === "SASL_PLAINTEXT" || proto === "SASL_SSL";
}

// saslMechanismClass — the JAAS login module for a SASL mechanism.
function saslMechanismClass(mechanism) {
	switch (String(mechanism || "").toUpperCase()) {
		case "PLAIN":
			return "org.apache.kafka.common.security.plain.PlainLoginModule";
		case "SCRAM-SHA-256":
		case "SCRAM-SHA-512":
			return "org.apache.kafka.common.security.scram.ScramLoginModule";
		default:
			return "";
	}
}

// listenerConfigPrefix — the per-listener config prefix Kafka expects
// (`listener.name.<lowercased-name>.`). Underscores are preserved; only the
// case is lowered.
function listenerConfigPrefix(name) {
	return "listener.name." + String(name).toLowerCase() + ".";
}

// isSize — true for a bare integer byte count (Kafka byte-valued properties).
function isSize(value) {
	return /^[0-9]+$/.test(String(value || ""));
}

// isPositiveInt — true for an integer >= 1.
function isPositiveInt(value) {
	return /^[0-9]+$/.test(String(value || "")) && parseInt(value, 10) >= 1;
}

// isNonNegativeInt — true for an integer >= 0.
function isNonNegativeInt(value) {
	return /^[0-9]+$/.test(String(value || ""));
}

module.exports = {
	parseListeners,
	parseSecurityMap,
	listenerProtocol,
	protocolRequiresTls,
	protocolRequiresSasl,
	saslMechanismClass,
	listenerConfigPrefix,
	isSize,
	isPositiveInt,
	isNonNegativeInt,
};
