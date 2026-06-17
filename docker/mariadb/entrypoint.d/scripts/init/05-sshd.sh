#!/bin/bash
# 05-sshd.sh - SSH daemon setup for replication

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_script_start "05-sshd.sh"

setup_sshd() {
    if [ "${MARIADB_EXTERNAL_ACCESS_ENABLE:-false}" != "true" ]; then
        log_info "External access (SSH) is not enabled, skipping SSH setup"
        log_script_end "05-sshd.sh"
        return 0
    fi

    log_info "Configuring SSH for replication"

    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        ssh-keygen -A
        chmod 0600 /etc/ssh/ssh_host_*_key
        chmod 0644 /etc/ssh/ssh_host_*.pub
    fi

    mkdir -p /opt/containers/data/.ssh
    chown mysql:mysql /opt/containers/data/.ssh
    chmod 0700 /opt/containers/data/.ssh

    log_info "SSH configuration completed"
    log_script_end "05-sshd.sh"
}

setup_sshd