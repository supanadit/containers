// database.js — init/02-database: initialize the MariaDB data directory and
// run the first-boot bootstrap SQL (root password, database, app user,
// MaxScale service user). Mirrors bash init/02-database.sh.
//
// Edge cases handled here:
//   - Create the configured database when MARIADB_DATABASE is set.
//   - MariaDB's mariadb-install-db creates root@localhost, root@127.0.0.1 and
//     root@::1 (and root@'%' when a host wildcard is present). The root
//     password must be applied to EVERY root account, not just root@localhost,
//     so a TCP connection as root can never fall through to an empty-password
//     account. We alter all known root hosts and, if a root@'%' account exists,
//     that too.
const { env, fs, process, log } = require("ezx");
const {
	MARIADB_DATA_DIR,
	MARIADB_RUN_DIR,
	MARIADB_ROOT_PASSWORD,
	MARIADB_DATABASE,
	MARIADB_USER,
	MARIADB_PASSWORD,
	MARIADB_ALLOW_EMPTY_PASSWORD,
	MARIADB_SOCKET,
	MARIADB_TZDATA_SQL,
	MAXSCALE_SERVICE_USER,
	MAXSCALE_SERVICE_PASSWORD,
} = require("./env");

const MYSQL_USER = "mysql";
const MYSQL_GROUP = "mysql";

// runAsMysql — run a one-shot command as the mysql user with an args array.
function runAsMysql(argv, name) {
	return process.run({
		name: name || "mysql-cmd",
		process: {
			binaryPath: argv[0],
			arguments: argv.slice(1),
			user: MYSQL_USER,
			group: MYSQL_GROUP,
		},
	});
}

// dataDirInitialized — true when the system tables exist (the `mysql` schema
// directory is present under the data dir).
function dataDirInitialized() {
	return fs.exists(MARIADB_DATA_DIR + "/mysql");
}

// sqlEscape — single-quote-escape a value for safe inclusion in SQL.
function sqlEscape(value) {
	return String(value).replace(/'/g, "''");
}

// backtickEscape — escape an identifier for safe inclusion in backticks.
function backtickEscape(value) {
	return String(value).replace(/`/g, "``");
}

// buildBootstrapSql — assemble the first-boot SQL statements.
function buildBootstrapSql() {
	const lines = [];

	// Root password: apply to every root account MariaDB creates. The default
	// install creates root@localhost, root@127.0.0.1, and root@::1. A
	// root@'%' account may exist if the install was customized; alter it too
	// (IF EXISTS so a missing account is not an error).
	const rootPass = MARIADB_ROOT_PASSWORD
		? sqlEscape(MARIADB_ROOT_PASSWORD)
		: (MARIADB_ALLOW_EMPTY_PASSWORD === "yes" ? "" : null);

	if (rootPass !== null) {
		// mariadb-install-db --rpm creates only root@localhost (unix_socket
		// auth). There is no root@'%', root@127.0.0.1, or root@::1, so a TCP
		// root connection would be denied. Create every root host with the
		// password so remote root access works, and set the password on the
		// existing root@localhost too. CREATE USER alone grants nothing, so
		// each new account also needs its privileges — without the GRANT the
		// account authenticates and then fails with "ERROR 1142 SELECT command
		// denied" (root@localhost keeps the full grants mariadb-install-db
		// already gave it).
		for (const host of ["localhost", "127.0.0.1", "::1", "%"]) {
			lines.push(`CREATE USER IF NOT EXISTS 'root'@'${host}' IDENTIFIED BY '${rootPass}';`);
			lines.push(`ALTER USER 'root'@'${host}' IDENTIFIED BY '${rootPass}';`);
			lines.push(
				`GRANT ALL PRIVILEGES ON *.* TO 'root'@'${host}' WITH GRANT OPTION;`,
			);
		}
	} else if (!MARIADB_ROOT_PASSWORD) {
		log.warn("No root password set and empty passwords not allowed; leaving root accounts unchanged");
	}

	// Create the configured database.
	if (MARIADB_DATABASE) {
		lines.push(`CREATE DATABASE IF NOT EXISTS \`${backtickEscape(MARIADB_DATABASE)}\`;`);
	}

	// Create the application user and grant on the database.
	if (MARIADB_USER && MARIADB_PASSWORD) {
		lines.push(
			`CREATE USER IF NOT EXISTS '${sqlEscape(MARIADB_USER)}'@'%' IDENTIFIED BY '${sqlEscape(MARIADB_PASSWORD)}';`,
		);
		if (MARIADB_DATABASE) {
			lines.push(
				`GRANT ALL PRIVILEGES ON \`${backtickEscape(MARIADB_DATABASE)}\`.* TO '${sqlEscape(MARIADB_USER)}'@'%';`,
			);
		}
	}

	// MaxScale service user (monitoring / routing).
	if (MAXSCALE_SERVICE_USER && MAXSCALE_SERVICE_PASSWORD) {
		lines.push(
			`CREATE USER IF NOT EXISTS '${sqlEscape(MAXSCALE_SERVICE_USER)}'@'%' IDENTIFIED BY '${sqlEscape(MAXSCALE_SERVICE_PASSWORD)}';`,
		);
		lines.push(
			`GRANT SELECT, RELOAD, PROCESS, SUPER, REPLICATION CLIENT, REPLICATION SLAVE, SLAVE MONITOR, SHOW DATABASES ON *.* TO '${sqlEscape(MAXSCALE_SERVICE_USER)}'@'%';`,
		);
	}

	lines.push("FLUSH PRIVILEGES;");
	return lines.join("\n");
}

// waitForSocket — poll until the MariaDB unix socket appears (bounded).
// Uses ezx.sleep() for non-blocking delays instead of spawning a sleep process.
function waitForSocket(maxAttempts, intervalSec) {
	for (let i = 0; i < maxAttempts; i++) {
		if (fs.exists(MARIADB_SOCKET)) return true;
		process.sleep(intervalSec * 1e9); // ezx.sleep takes nanoseconds
	}
	return fs.exists(MARIADB_SOCKET);
}

// runBootstrapSql — start a temporary mariadbd (skip-networking, unix socket
// only), run the bootstrap SQL as root, then stop it. Mirrors the bash
// temp-server pattern without a hardcoded sleep.
function runBootstrapSql(sql) {
	fs.ensureDir(MARIADB_RUN_DIR, { mode: 0o755 });
	fs.chown(MARIADB_RUN_DIR, MYSQL_USER + ":" + MYSQL_GROUP);

	const server = process.spawn({
		name: "mariadb-bootstrap",
		process: {
			binaryPath: "mariadbd",
			arguments: [
				"--user=mysql",
				"--datadir=" + MARIADB_DATA_DIR,
				"--skip-networking",
				"--socket=" + MARIADB_SOCKET,
				"--pid-file=" + MARIADB_RUN_DIR + "/mysqld-bootstrap.pid",
			],
			user: MYSQL_USER,
			group: MYSQL_GROUP,
		},
	});
	server.start([]);

	try {
		if (!waitForSocket(30, 1)) {
			throw new Error("MariaDB bootstrap server did not create socket at " + MARIADB_SOCKET);
		}

		// Load the timezone tables from the SQL baked into the image at build
		// time (forge.toml: mysql_tzinfo_to_sql over /usr/share/zoneinfo).
		// It is NOT generated here because ezx's process.capture truncates a
		// stream at 1 MiB (with an in-band marker) while the full dump is
		// ~4.8 MB: the client then died on the marker mid-statement and —
		// because `-e "source …"` still exits 0 — the entrypoint saw success
		// with empty time_zone tables, so mariadbd later aborted with
		// "Illegal or unknown default time zone '<zone>'". ezx also has no
		// stdin/fd plumbing, so the file is fed to the mariadb client through
		// the client's own `source` command. The client MUST run as the
		// container's root user (not mysql): mariadb-install-db --rpm creates
		// root@localhost with unix_socket auth, which requires the OS user to
		// match the MySQL user.
		if (!fs.exists(MARIADB_TZDATA_SQL)) {
			throw new Error(
				"Timezone data missing from image at " +
					MARIADB_TZDATA_SQL +
					" (expected to be generated at build time by forge.toml)",
			);
		}
		const tzCode = process.run({
			process: {
				binaryPath: "mariadb",
				arguments: [
					"--socket=" + MARIADB_SOCKET,
					"-u",
					"root",
					"mysql",
					"-e",
					"source " + MARIADB_TZDATA_SQL,
				],
			},
		});
		if (tzCode !== 0) throw new Error("Failed to load timezone tables (code=" + tzCode + ")");

		// Run bootstrap SQL without shell: write the SQL to a temp file and run
		// it through the client's `source` command (no stdin, no redirection).
		const sqlFile = fs.tempFile("/tmp", "mariadb-init");
		try {
			fs.write(sqlFile, sql, { mode: 0o600 });
			const code = process.run({
				process: {
					binaryPath: "mariadb",
					arguments: ["--socket=" + MARIADB_SOCKET, "-u", "root", "-e", "source " + sqlFile],
				},
			});
			if (code !== 0) throw new Error("Failed to run bootstrap SQL (code=" + code + ")");
		} finally {
			fs.remove(sqlFile);
		}
	} finally {
		// Graceful stop of the temp server.
		try {
			server.signal("SIGTERM");
			server.wait();
		} catch {
			/* already stopped */
		}
		// The socket is removed by the server on shutdown; tolerate it already
		// being gone.
		try {
			fs.remove(MARIADB_SOCKET);
		} catch {
			/* already removed */
		}
	}
}

// initdb — initialize the data directory if needed, then run bootstrap SQL.
// Mirrors bash init/02-database.sh: the bootstrap SQL runs only on a fresh
// init (data dir was just created). On a restart with an existing data dir
// the accounts already exist, so it is skipped.
function initdb() {
	if (!dataDirInitialized()) {
		log.info("Initializing MariaDB data directory at " + MARIADB_DATA_DIR);
		fs.ensureDir(MARIADB_DATA_DIR, { mode: 0o755 });
		fs.chownRecursive(MARIADB_DATA_DIR, MYSQL_USER + ":" + MYSQL_GROUP);

		const code = runAsMysql(
			["mariadb-install-db", "--user=mysql", "--datadir=" + MARIADB_DATA_DIR, "--rpm"],
			"mariadb-install-db",
		);
		if (code !== 0) throw new Error("mariadb-install-db failed (code=" + code + ")");
		log.info("Database initialized successfully");

		log.info("Setting up initial database configuration");
		runBootstrapSql(buildBootstrapSql());
		log.info("Initial database setup completed");
	} else {
		log.info("Database already initialized, skipping initialization");
	}
}

module.exports = {
	initdb,
	dataDirInitialized,
	buildBootstrapSql,
	runBootstrapSql,
};
