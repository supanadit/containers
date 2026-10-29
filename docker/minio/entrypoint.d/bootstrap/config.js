// config.js — MinIO runtime configuration that must be computed before start:
//
//   * the browser redirect URL default (derived from the container IP, matching
//     the bash `hostname -i`),
//   * file-based credentials (0600 on the config volume) when the *_FILE
//     variables are not already pointing at an operator-supplied mount.
//
// Everything else is passed to the process directly: ezx builds the argv and
// sets the process environment explicitly, so the old `unset MINIO_*` dance (bash
// had to remove its own variables so they would not conflict with the
// command-line flags) is unnecessary.
const { fs, process, log } = require("ezx");
const {
	MINIO_CONFIG_DIR,
	MINIO_USER,
	MINIO_GROUP,
	MINIO_CONSOLE_ADDRESS,
	MINIO_BROWSER_REDIRECT_URL,
	MINIO_DISTRIBUTED_MODE_ENABLED,
	MINIO_LOG_LEVEL,
	MINIO_ROOT_USER,
	MINIO_ROOT_PASSWORD,
	MINIO_ROOT_USER_FILE,
	MINIO_ROOT_PASSWORD_FILE,
	portOf,
} = require("./env");

const OWNER = MINIO_USER + ":" + MINIO_GROUP;

// containerIp — the container's primary IP, without a shell. `hostname` is a
// coreutils binary, not a shell builtin, so process.capture is sufficient.
function containerIp() {
	const res = process.capture({
		process: { binaryPath: "hostname", arguments: ["-i"] },
	});
	if (res.code !== 0) return "";
	return String(res.stdout || "").trim();
}

// browserRedirectUrl — resolve the console redirect URL. In standalone mode it
// defaults to http://<container-ip>:<console-port>; in distributed mode it is
// left alone (a per-node IP would make the console links disagree across nodes).
function browserRedirectUrl() {
	if (MINIO_BROWSER_REDIRECT_URL) return MINIO_BROWSER_REDIRECT_URL;
	if (MINIO_DISTRIBUTED_MODE_ENABLED) return "";

	const port = portOf(MINIO_CONSOLE_ADDRESS) || "9001";
	const ip = containerIp();
	if (!ip) {
		log.warn("Could not determine the container IP; set MINIO_BROWSER_REDIRECT_URL explicitly.");
		return "";
	}
	return "http://" + ip + ":" + port;
}

// materializeCredentials — when inline credentials were supplied, write them to
// 0600 files on the config volume and hand MinIO the *_FILE paths instead. The
// secret then never appears in the process list or `docker inspect`.
//
// The *_FILE variables take precedence: an operator-supplied mount is used as-is
// and never rewritten.
function materializeCredentials() {
	const result = { userFile: "", passwordFile: "" };

	if (MINIO_ROOT_USER_FILE) {
		result.userFile = MINIO_ROOT_USER_FILE;
	} else if (MINIO_ROOT_USER) {
		result.userFile = MINIO_CONFIG_DIR + "/root-user";
		fs.write(result.userFile, MINIO_ROOT_USER + "\n", { mode: 0o600, owner: OWNER });
		fs.chmod(result.userFile, 0o600);
		fs.chown(result.userFile, OWNER);
	}

	if (MINIO_ROOT_PASSWORD_FILE) {
		result.passwordFile = MINIO_ROOT_PASSWORD_FILE;
	} else if (MINIO_ROOT_PASSWORD) {
		result.passwordFile = MINIO_CONFIG_DIR + "/root-password";
		fs.write(result.passwordFile, MINIO_ROOT_PASSWORD + "\n", { mode: 0o600, owner: OWNER });
		fs.chmod(result.passwordFile, 0o600);
		fs.chown(result.passwordFile, OWNER);
	}

	return result;
}

// runtimeEnvironment — the environment for the MinIO process. Only the values
// MinIO reads are forwarded; the container's own configuration variables
// (MINIO_DATA_DIR, MINIO_ADDRESS, ...) are deliberately not inherited so they
// cannot be mistaken for MinIO's own settings.
//
// MINIO_LOG_LEVEL is MinIO's own log level and is forwarded as-is when set. The
// variable must not be listed in filterEnvPatterns(), or this entry would be
// removed again at spawn time.
function runtimeEnvironment(creds, redirectUrl) {
	const env = [];

	env.push("MINIO_ROOT_USER_FILE=" + creds.userFile);
	env.push("MINIO_ROOT_PASSWORD_FILE=" + creds.passwordFile);

	if (redirectUrl) {
		env.push("MINIO_BROWSER_REDIRECT_URL=" + redirectUrl);
	}
	if (MINIO_LOG_LEVEL) {
		env.push("MINIO_LOG_LEVEL=" + MINIO_LOG_LEVEL);
	}

	return env;
}

// filterEnvPatterns — variable names that must never reach the MinIO process.
// These are container-side configuration; MinIO either does not read them or
// reads a namesake with different semantics.
function filterEnvPatterns() {
	return [
		"^MINIO_DATA_DIR$",
		"^MINIO_ADDRESS$",
		"^MINIO_CONSOLE_ADDRESS$",
		"^MINIO_ROOT_USER$",
		"^MINIO_ROOT_PASSWORD$",
		"^MINIO_ACCESS_KEY$",
		"^MINIO_SECRET_KEY$",
		"^MINIO_DISTRIBUTED_MODE_ENABLED$",
		"^MINIO_DISTRIBUTED_NODES$",
		"^MINIO_BROWSER_REDIRECT_URL$",
		"^MINIO_EXTRA_DRIVES$",
		"^MINIO_EXTRA_ARGS$",
		"^MINIO_CONFIG_DIR$",
		"^MINIO_LOG_DIR$",
		"^MINIO_RUN_DIR$",
		"^MINIO_BACKUP_DIR$",
		"^MINIO_USER$",
		"^MINIO_GROUP$",
	];
}

module.exports = {
	browserRedirectUrl,
	materializeCredentials,
	runtimeEnvironment,
	filterEnvPatterns,
	containerIp,
	OWNER,
};
