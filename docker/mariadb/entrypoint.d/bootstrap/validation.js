// validation.js — port of the bash utils/validation.sh for MariaDB. Validates
// the container environment and required dependencies before any side effects.
const { env, log, scheduler, fs } = require("ezx");

// validateCronExpression — delegate to ezx's cron engine so validation always
// matches what the scheduler actually runs.
function validateCronExpression(expr) {
	try {
		scheduler.parse(expr);
		return true;
	} catch {
		return false;
	}
}

// validateMemoryValue — accepts MariaDB/MySQL size shorthand and long forms:
// "512", "128M", "48M", "256MB", "1GB", "2T", "4KB", etc. (case-insensitive).
function validateMemoryValue(value) {
	return /^[0-9]+(K|M|G|T|KB|MB|GB|TB)?$/i.test(String(value || ""));
}

function validateEnvironment() {
	let failed = false;
	const fail = (msg) => {
		log.error(msg);
		failed = true;
	};
	const warn = (msg) => log.warn(msg);

	// LOG_LEVEL
	const logLevel = env.get("LOG_LEVEL", "INFO").toUpperCase();
	if (!["DEBUG", "INFO", "WARN", "ERROR"].includes(logLevel)) {
		fail(`Invalid LOG_LEVEL: ${env.get("LOG_LEVEL")} (must be DEBUG, INFO, WARN, or ERROR)`);
	}

	// SLEEP_MODE
	const sleepMode = env.get("SLEEP_MODE", "false");
	if (!["true", "false"].includes(sleepMode.toLowerCase())) {
		fail(`Invalid SLEEP_MODE: ${sleepMode} (must be true or false)`);
	}

	// MARIADB_ALLOW_EMPTY_PASSWORD
	const allowEmpty = env.get("MARIADB_ALLOW_EMPTY_PASSWORD", "no");
	if (!["yes", "no", "true", "false", "1", "0"].includes(allowEmpty.toLowerCase())) {
		fail(`Invalid MARIADB_ALLOW_EMPTY_PASSWORD: ${allowEmpty} (must be yes|no)`);
	}

	// MARIADB_PORT
	const port = env.get("MARIADB_PORT", "3306");
	if (!/^[0-9]+$/.test(port) || env.int("MARIADB_PORT", 3306) <= 0 || env.int("MARIADB_PORT", 3306) > 65535) {
		fail(`Invalid MARIADB_PORT: ${port} (must be a valid port 1-65535)`);
	}

	// MARIADB_MAX_CONNECTIONS
	const maxConn = env.get("MARIADB_MAX_CONNECTIONS");
	if (maxConn && (!/^[0-9]+$/.test(maxConn) || env.int("MARIADB_MAX_CONNECTIONS", 0) <= 0)) {
		fail(`Invalid MARIADB_MAX_CONNECTIONS: ${maxConn} (must be a positive integer)`);
	}

	// Memory values
	for (const v of ["MARIADB_INNODB_BUFFER_POOL_SIZE", "MARIADB_INNODB_LOG_FILE_SIZE"]) {
		const val = env.get(v);
		if (val && !validateMemoryValue(val)) {
			fail(`Invalid ${v}: ${val}`);
		}
	}

	// MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT
	const flushLog = env.get("MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT", "1");
	if (!["0", "1", "2"].includes(flushLog)) {
		fail(`Invalid MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT: ${flushLog} (must be 0, 1, or 2)`);
	}

	// MARIADB_EXPIRE_LOGS_DAYS
	const expireLogs = env.get("MARIADB_EXPIRE_LOGS_DAYS", "7");
	if (!/^[0-9]+$/.test(expireLogs) || env.int("MARIADB_EXPIRE_LOGS_DAYS", 7) < 0) {
		fail(`Invalid MARIADB_EXPIRE_LOGS_DAYS: ${expireLogs} (must be a non-negative integer)`);
	}

	// MARIADB_GALERA_SST_METHOD
	const sstMethod = env.get("MARIADB_GALERA_SST_METHOD", "mariabackup");
	if (!["xtrabackup", "xtrabackup-v2", "mariabackup", "rsync"].includes(sstMethod)) {
		fail(`Invalid MARIADB_GALERA_SST_METHOD: ${sstMethod} (must be xtrabackup|xtrabackup-v2|mariabackup|rsync)`);
	}

	// MARIADB_GALERA_THREADS
	const threads = env.get("MARIADB_GALERA_THREADS", "4");
	if (!/^[0-9]+$/.test(threads) || env.int("MARIADB_GALERA_THREADS", 4) <= 0) {
		fail(`Invalid MARIADB_GALERA_THREADS: ${threads} (must be a positive integer)`);
	}

	// Backup schedule/retention/method — only when the scheduler is enabled.
	if (env.bool("MARIADB_BACKUP_ENABLE")) {
		const schedule = env.get("MARIADB_BACKUP_SCHEDULE", "0 2 * * *");
		if (!validateCronExpression(schedule)) {
			fail(`Invalid MARIADB_BACKUP_SCHEDULE: ${schedule} (must be a valid 5-field cron expression)`);
		}
		// Incrementals extend a chain, so a full schedule must exist to start
		// one; an incr-only configuration would never have a base.
		const incrSchedule = env.get("MARIADB_BACKUP_INCR_SCHEDULE", "");
		if (incrSchedule !== "") {
			if (!validateCronExpression(incrSchedule)) {
				fail(
					`Invalid MARIADB_BACKUP_INCR_SCHEDULE: ${incrSchedule} (must be a valid 5-field cron expression)`,
				);
			}
			if (schedule === "") {
				fail(
					"MARIADB_BACKUP_INCR_SCHEDULE is set but MARIADB_BACKUP_SCHEDULE is empty: incrementals need a full backup to start a chain",
				);
			}
		}
		const retention = env.get("MARIADB_BACKUP_RETENTION_DAYS", "7");
		if (!/^[0-9]+$/.test(retention) || env.int("MARIADB_BACKUP_RETENTION_DAYS", 7) <= 0) {
			fail(`Invalid MARIADB_BACKUP_RETENTION_DAYS: ${retention} (must be a positive integer)`);
		}
		const backupMethod = env.get("MARIADB_BACKUP_METHOD", "mariabackup");
		// The managed scheduler drives the physical hot-backup tool only, like
		// the PostgreSQL image drives pgBackRest. mariabackup is MariaDB's own
		// fork of Percona XtraBackup; logical dumps are NOT managed by us (the
		// mariadb-dump/mysqldump binaries stay in the image for users to run
		// themselves or wire into their own sidecar).
		if (["mysqldump", "mariadb-dump", "dump"].includes(backupMethod)) {
			fail(
				`MARIADB_BACKUP_METHOD=${backupMethod} is not managed by this container (it only schedules the physical hot-backup tool, mariabackup); the dump binaries remain in the image for you to run or extend yourself`,
			);
		} else if (backupMethod === "xtrabackup") {
			fail(
				"MARIADB_BACKUP_METHOD=xtrabackup is not supported: Percona XtraBackup does not support MariaDB servers; use mariabackup (MariaDB's fork of XtraBackup)",
			);
		} else if (backupMethod !== "mariabackup") {
			fail(`Invalid MARIADB_BACKUP_METHOD: ${backupMethod} (must be mariabackup)`);
		}
	}

	// Cross-variable warnings
	if (env.bool("MARIADB_GALERA_ENABLE") && !env.get("MARIADB_GALERA_SEEDS")) {
		warn("MARIADB_GALERA_ENABLE=true but MARIADB_GALERA_SEEDS is empty; node will start as a standalone Galera node");
	}

	return !failed;
}

// validateDependencies — required binaries exist before starting.
function validateDependencies() {
	let failed = false;
	const fail = (msg) => {
		log.error(msg);
		failed = true;
	};

	const required = ["mariadbd", "mariadb-install-db", "mariadb"];

	for (const cmd of required) {
		if (!fs.which(cmd)) {
			fail(`Required command not found: ${cmd}`);
		}
	}

	// Galera ships as a loadable provider library, not a CLI binary, so check
	// the file directly. The path is configurable, so a custom MARIADB_GALERA_PROVIDER
	// is honoured rather than assumed.
	if (env.bool("MARIADB_GALERA_ENABLE")) {
		const provider = env.get("MARIADB_GALERA_PROVIDER", "/usr/local/lib/libgalera_smm.so");
		if (!fs.exists(provider)) {
			fail(`MARIADB_GALERA_ENABLE=true but wsrep provider not found: ${provider}`);
		}
	}

	// Backup: the managed scheduler only drives the physical hot-backup tool,
	// so that binary must exist up front (fail at startup, not on the first
	// cron tick). Dump tooling is deliberately not managed — it stays in the
	// image for users to run themselves, exactly like pg_dump/pg_restore in
	// the PostgreSQL image.
	if (env.bool("MARIADB_BACKUP_ENABLE")) {
		const method = env.get("MARIADB_BACKUP_METHOD", "mariabackup");
		if (!fs.which(method)) {
			fail(
				`MARIADB_BACKUP_ENABLE=true and MARIADB_BACKUP_METHOD=${method} but that binary is not in this image (the scheduler does not fall back to a dump)`,
			);
		}
	}

	return !failed;
}

module.exports = {
	validateEnvironment,
	validateDependencies,
	validateCronExpression,
	validateMemoryValue,
};
