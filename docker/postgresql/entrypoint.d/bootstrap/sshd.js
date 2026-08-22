// sshd.js — init/05-sshd: generate host keys, move them to /run/ssh, write
// sshd_config (config.js), and generate replica SSH keys (mirrors the bash
// init/05-sshd.sh).
const { fs, editor, log } = require("ezx");
const { runPg } = require("./database");
const { PG_GROUP } = require("./env");

function sshdKeys() {
	const run = "/run/ssh";
	fs.mkdirAll(run, 0o755);

	// sshd privilege-separation directory (distinct from /run/ssh where host
	// keys live). /run is tmpfs and empty on each container start, so sshd
	// fails with "Missing privilege separation directory: /run/sshd" without it.
	fs.mkdirAll("/run/sshd", 0o755);

	// Generate host keys once, then move them to /run/ssh with root ownership
	// and strict modes (bash 05-sshd.sh:27-41). ssh-keygen -A writes to
	// /etc/ssh/ssh_host_*.
	if (!fs.exists(run + "/ssh_host_rsa_key")) {
		runPg("ssh-keygen -A", "ssh-keygen");
		for (const base of ["rsa", "ecdsa", "ed25519"]) {
			const src = "/etc/ssh/ssh_host_" + base + "_key";
			const pub = src + ".pub";
			if (fs.exists(src)) {
				fs.rename(src, run + "/ssh_host_" + base + "_key");
				fs.chmod(run + "/ssh_host_" + base + "_key", 0o600);
			}
			if (fs.exists(pub)) {
				fs.rename(pub, run + "/ssh_host_" + base + "_key.pub");
				fs.chmod(run + "/ssh_host_" + base + "_key.pub", 0o644);
			}
		}
		fs.chown(run, "root:root");
	}

	// Replica keypair for SSH-based pgBackRest standby.
	const dir = "/home/postgres/.ssh";
	fs.mkdirAll(dir, 0o700);
	fs.chmod(dir, 0o700);
	fs.chown(dir, "postgres:" + PG_GROUP);

	const keyFile = dir + "/id_rsa";
	if (!fs.exists(keyFile)) {
		if (!fs.exists("/usr/bin/ssh-keygen") && !fs.exists("/usr/bin/ssh-keygen")) {
			log.warn("ssh-keygen not found, skipping SSH key generation");
			return;
		}
		runPg(
			"ssh-keygen -t rsa -b 4096 -f " + keyFile + " -N '' -C 'postgres@replica-auth'",
			"ssh-key",
		);
		fs.chmod(keyFile, 0o600);
		fs.chown(keyFile, "postgres:" + PG_GROUP);
	}

	const pubKey = keyFile + ".pub";
	if (fs.exists(pubKey)) fs.chmod(pubKey, 0o644);

	// Append the public key to authorized_keys (accumulates, like bash).
	const authFile = dir + "/authorized_keys";
	if (!fs.exists(authFile)) {
		editor.open(authFile).replace("");
		fs.chown(authFile, "postgres:" + PG_GROUP);
		fs.chmod(authFile, 0o600);
	}
	if (fs.exists(pubKey)) {
		const pub = editor.open(pubKey).read().trim();
		const auth = editor.open(authFile).read();
		if (!auth.includes(pub)) {
			editor.open(authFile).append(pub + "\n");
		}
	}
	fs.chown(authFile, "postgres:" + PG_GROUP);
	fs.chmod(authFile, 0o600);
}

module.exports = { sshdKeys };