#!/bin/bash
# 05-sshd.sh - SSHD configuration for primary nodes
# Configures SSH daemon on primary to allow replica backup access
# Note: SSHD is started in runtime phase, not here

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

main() {
    log_script_start "05-sshd.sh"

    configure_sshd
    setup_ssh_keys_for_replicas

    log_script_end "05-sshd.sh"
}

configure_sshd() {
    log_info "Preparing SSH daemon configuration"

    local sshd_config="/etc/ssh/sshd_config"
    local ssh_dir="/run/ssh"

    mkdir -p "$ssh_dir"

    if [ ! -f "$ssh_dir/ssh_host_rsa_key" ]; then
        log_info "Generating SSH host keys"
        ssh-keygen -A 2>/dev/null || true
        mv /etc/ssh/ssh_host_rsa_key "$ssh_dir/" 2>/dev/null || true
        mv /etc/ssh/ssh_host_ecdsa_key "$ssh_dir/" 2>/dev/null || true
        mv /etc/ssh/ssh_host_ed25519_key "$ssh_dir/" 2>/dev/null || true
        mv /etc/ssh/ssh_host_rsa_key.pub "$ssh_dir/" 2>/dev/null || true
        mv /etc/ssh/ssh_host_ecdsa_key.pub "$ssh_dir/" 2>/dev/null || true
        mv /etc/ssh/ssh_host_ed25519_key.pub "$ssh_dir/" 2>/dev/null || true
        chown root:root "$ssh_dir"/ssh_host_*
        chmod 600 "$ssh_dir"/ssh_host_*_key
        chmod 644 "$ssh_dir"/ssh_host_*.pub
    else
        log_debug "SSH host keys already exist"
    fi

    cat > "$sshd_config" << 'EOF'
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

Protocol 2
HostKey /run/ssh/ssh_host_rsa_key
HostKey /run/ssh/ssh_host_ecdsa_key
HostKey /run/ssh/ssh_host_ed25519_key

SyslogFacility AUTH
LogLevel INFO

PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

Subsystem sftp /usr/lib/openssh/sftp-server

AllowUsers postgres
EOF

    chmod 644 "$sshd_config"
    log_info "SSH daemon configured (will start on primary at runtime)"
}

setup_ssh_keys_for_replicas() {
    local ssh_dir="/home/postgres/.ssh"
    local key_file="$ssh_dir/id_rsa"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [ -f "$key_file" ]; then
        log_debug "PostgreSQL user SSH key already exists"
        return 0
    fi

    log_info "Generating SSH keypair for replica authentication"

    if ! command -v ssh-keygen >/dev/null 2>&1; then
        log_warn "ssh-keygen not found, skipping SSH key generation"
        return 0
    fi

    ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "postgres@$(hostname)-replica-auth"
    chown postgres:postgres "$key_file"
    chmod 600 "$key_file"

    local pub_key="$key_file.pub"
    chmod 644 "$pub_key"

    if [ ! -f "$ssh_dir/authorized_keys" ]; then
        echo -n "" > "$ssh_dir/authorized_keys"
        chown postgres:postgres "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
    fi

    cat "$pub_key" >> "$ssh_dir/authorized_keys"

    log_info "SSH keypair generated for replica authentication"
    log_debug "Public key: $(cat "$pub_key")"
}

main "$@"