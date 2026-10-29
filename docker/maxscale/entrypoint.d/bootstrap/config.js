// config.js — generate the MaxScale configuration (INI) from environment.
//
// Replaces the bash heredoc in generate_config / parse_server_definitions /
// get_server_names. The server list is derived from
// MAXSCALE_SERVICE_READWRITE_ROUTES (comma-separated host:port), producing one
// [serverN] section per entry and the matching servers= list, exactly as the
// bash version did.
const { fs, config, log } = require("ezx");
const {
	MAXSCALE_CONFIG_FILE,
	MAXSCALE_CONFIG_DIR,
	MAXSCALE_SERVICE_USER,
	MAXSCALE_SERVICE_PASSWORD,
	MAXSCALE_SERVICE_READWRITE_ROUTES,
	MAXSCALE_THREADS,
} = require("./env");

// parseRoutes — [{host, port}] from a comma-separated host:port list.
function parseRoutes(spec) {
	const out = [];
	for (const entry of String(spec || "").split(",")) {
		const part = entry.trim();
		if (part === "") continue;
		const idx = part.lastIndexOf(":");
		const host = idx >= 0 ? part.slice(0, idx) : part;
		const port = idx >= 0 ? part.slice(idx + 1) : "3306";
		out.push({ host: host, port: port || "3306" });
	}
	return out;
}

// serverNames — "server1,server2,..." for the servers= field.
function serverNames(routes) {
	return routes.map((_, i) => "server" + (i + 1)).join(",");
}

// serverSections — the [serverN] sections.
function serverSections(routes) {
	const sections = {};
	routes.forEach((r, i) => {
		sections["server" + (i + 1)] = {
			type: "server",
			address: r.host,
			port: r.port,
		};
	});
	return sections;
}

// maxscaleConfig — assemble the full INI document. Sections are passed as an
// ordered array because config.build sorts a section map alphabetically, and
// MaxScale requires [maxscale] to be the first section.
function maxscaleConfig() {
	const routes = parseRoutes(MAXSCALE_SERVICE_READWRITE_ROUTES);
	const names = serverNames(routes);

	const sections = [];
	sections.push([
		"maxscale",
		{
			threads: MAXSCALE_THREADS,
			log_info: "true",
			log_notice: "true",
			log_warning: "true",
			syslog: "false",
			logdir: "/var/log/maxscale",
			admin_auth: "true",
			admin_enabled: "true",
		},
	]);
	sections.push([
		"Read-Write-Service",
		{
			type: "service",
			router: "readwritesplit",
			servers: names,
			user: MAXSCALE_SERVICE_USER,
			password: MAXSCALE_SERVICE_PASSWORD,
		},
	]);
	sections.push([
		"Read-Connection-Service",
		{
			type: "service",
			router: "readconnroute",
			servers: names,
			router_options: "slave",
			user: MAXSCALE_SERVICE_USER,
			password: MAXSCALE_SERVICE_PASSWORD,
		},
	]);
	sections.push([
		"MariaDB-Monitor",
		{
			type: "monitor",
			module: "mariadbmon",
			servers: names,
			monitor_interval: "10s",
			switchover_timeout: "3600s",
			user: MAXSCALE_SERVICE_USER,
			password: MAXSCALE_SERVICE_PASSWORD,
		},
	]);
	for (const [name, props] of Object.entries(serverSections(routes))) {
		sections.push([name, props]);
	}
	sections.push([
		"Read-Write-Listener",
		{ type: "listener", service: "Read-Write-Service", protocol: "MariaDB", port: "3306" },
	]);
	sections.push([
		"Read-Connection-Listener",
		{ type: "listener", service: "Read-Connection-Service", protocol: "MariaDB", port: "3308" },
	]);

	return config.build({ separator: "=", valueFormat: "none", sections: sections });
}

// generateConfig — write the generated MaxScale config.
function generateConfig() {
	const content = maxscaleConfig();
	try {
		fs.ensureDir(MAXSCALE_CONFIG_DIR, { mode: 0o755 });
		fs.ensureDir("/etc/maxscale.cnf.d", { mode: 0o755 });
		fs.write(MAXSCALE_CONFIG_FILE, content, { mode: 0o640 });
		fs.chown(MAXSCALE_CONFIG_FILE, "maxscale:maxscale");
		fs.chmod(MAXSCALE_CONFIG_FILE, 0o640);
	} catch (e) {
		throw new Error("cannot write " + MAXSCALE_CONFIG_FILE + " (" + e.message + ")");
	}
	log.info("Generated MaxScale configuration at " + MAXSCALE_CONFIG_FILE);
}

module.exports = {
	generateConfig,
	maxscaleConfig,
	parseRoutes,
	serverNames,
	serverSections,
};
