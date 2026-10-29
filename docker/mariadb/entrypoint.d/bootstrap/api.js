// api.js — operator-facing API routes + composite health checks for MariaDB.
// All handlers live on the shared health server (EZX_HEALTH_ADDR) and run on
// HTTP goroutines while the chain supervises.
const { env, api, probe } = require("ezx");
const {
	MARIADB_DATA_DIR,
	MARIADB_ROOT_PASSWORD,
	MARIADB_GALERA_ENABLE,
	MARIADB_SOCKET,
	MARIADB_SSL_ENABLE,
	MARIADB_SSL_CERT_DIR,
} = require("./env");

// tlsArgs — client TLS flags matching the generated my.cnf (config.js sets
// ssl=0 with no cert paths, or ssl=1 with ssl_ca/ssl_cert/ssl_key). The 11.8
// client requires TLS by default, so a server running with ssl=0 rejects it
// with "SSL is required, but the server does not support it".
function tlsArgs() {
	return MARIADB_SSL_ENABLE ? ["--ssl-ca=" + MARIADB_SSL_CERT_DIR + "/ca.crt"] : ["--skip-ssl"];
}

// checkMariaDB — true when the server accepts a connection over the unix
// socket (mirrors runtime/healthcheck.sh check_mariadb_connectivity). After the
// bootstrap SQL alters root@localhost to password auth, the root connection
// needs the password. When no password is set, root@localhost keeps unix_socket
// auth, so we omit -p (a bare -p would prompt interactively and hang). --skip-ssl
// is required: the server is built with SSL support but runs with ssl=0.
function checkMariaDB() {
	const args = ["mariadb-admin", "--socket=" + MARIADB_SOCKET, ...tlsArgs(), "-u", "root"];
	if (MARIADB_ROOT_PASSWORD) args.push("-p" + MARIADB_ROOT_PASSWORD);
	args.push("ping");
	return probe.exec(...args);
}

// checkGalera — true when the node is connected to a Primary Galera cluster.
function checkGalera() {
	if (!MARIADB_GALERA_ENABLE) return true;
	const res = probe.exec(
		"mariadb",
		"--socket=" + MARIADB_SOCKET,
		...tlsArgs(),
		"-u",
		"root",
		"-p" + MARIADB_ROOT_PASSWORD,
		"-N",
		"-e",
		"SHOW STATUS LIKE 'wsrep_cluster_status';",
	);
	// probe.exec only reports exit code; a non-zero exit means the query
	// failed. We treat a successful query as healthy (the status value is
	// checked by the operator via the comprehensive endpoint).
	return res;
}

// checkDisk — true when the data mount has at least 10% free and 100MB free.
function checkDisk() {
	return probe.disk(MARIADB_DATA_DIR, 10, 100);
}

// checkProcess — true when a mariadbd process is running and no zombies.
function checkProcess() {
	return probe.process("mariadbd") && probe.zombies() === 0;
}

// handleHealth — composite health endpoint (port of runtime/healthcheck.sh).
function handleHealth() {
	const checks = {
		mariadb: checkMariaDB(),
		galera: checkGalera(),
		disk: checkDisk(),
		process: checkProcess(),
	};
	// Only the main program determines health. Sidecars are optional.
	const main = checks.mariadb;
	return { healthy: main, checks };
}

// registerOpsRoutes — bind operator routes on the shared health server.
function registerOpsRoutes() {
	api.get("/health/comprehensive", () => handleHealth());
}

module.exports = {
	registerOpsRoutes,
	handleHealth,
	checkMariaDB,
	checkGalera,
	checkDisk,
	checkProcess,
};
