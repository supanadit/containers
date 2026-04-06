#!/bin/bash
# pg-reload-sync-config.sh - Dynamically reload synchronous replication configuration
# 
# This script allows changing synchronous replication settings at runtime without
# restarting PostgreSQL. It updates postgresql.conf and triggers a reload.
#
# Usage:
#   pg-reload-sync-config.sh [OPTIONS]
#
# Options:
#   --sync-mode MODE         Enable/disable sync replication (true/false)
#   --sync-count N           Number of replicas required for sync (when using quorum)
#   --sync-replicas NAMES    Comma-separated replica application names
#   --help                   Show this help message
#
# If options are not provided, reads from environment variables:
#   REPLICATION_SYNCHRONOUS_MODE
#   REPLICATION_SYNCHRONOUS_COUNT
#   REPLICATION_SYNCHRONOUS_REPLICAS
#
# Examples:
#   # Disable sync replication
#   pg-reload-sync-config.sh --sync-mode=false
#
#   # Enable quorum sync with 2 replicas
#   pg-reload-sync-config.sh --sync-mode=true --sync-count=2 --sync-replicas="replica1,replica2"
#
#   # Change number of required sync replicas
#   pg-reload-sync-config.sh --sync-mode=true --sync-count=1 --sync-replicas="replica1"
#
# Note: After reloading, verify with:
#   SELECT client_addr, state, sync_state FROM pg_stat_replication;

set -euo pipefail

PGDATA="${PGDATA:-/usr/local/pgsql/data}"
POSTGRES_BIN="${POSTGRES_BIN:-/usr/local/pgsql/bin}"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*"
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

show_help() {
    sed -n '/^#!.*/,/^$/p' "$0" | sed '1d;s/^# //;s/^#$//'
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --sync-mode=*)
                SYNC_MODE="${1#*=}"
                shift
                ;;
            --sync-mode)
                SYNC_MODE="$2"
                shift 2
                ;;
            --sync-count=*)
                SYNC_COUNT="${1#*=}"
                shift
                ;;
            --sync-count)
                SYNC_COUNT="$2"
                shift 2
                ;;
            --sync-replicas=*)
                SYNC_REPLICAS="${1#*=}"
                shift
                ;;
            --sync-replicas)
                SYNC_REPLICAS="$2"
                shift 2
                ;;
            --*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

validate_config() {
    local sync_mode="${SYNC_MODE:-${REPLICATION_SYNCHRONOUS_MODE:-true}}"
    
    if [[ "$sync_mode" != "true" && "$sync_mode" != "false" ]]; then
        log_error "Invalid REPLICATION_SYNCHRONOUS_MODE: $sync_mode (must be true or false)"
        return 1
    fi
    
    if [[ "$sync_mode" == "true" ]]; then
        local sync_count="${SYNC_COUNT:-${REPLICATION_SYNCHRONOUS_COUNT:-}}"
        
        if [[ -n "$sync_count" ]]; then
            if ! [[ "$sync_count" =~ ^[0-9]+$ ]] || [[ "$sync_count" -lt 1 ]]; then
                log_error "Invalid REPLICATION_SYNCHRONOUS_COUNT: $sync_count (must be a positive integer)"
                return 1
            fi
        fi
    fi
    
    return 0
}

generate_ssn_value() {
    local sync_mode="${SYNC_MODE:-${REPLICATION_SYNCHRONOUS_MODE:-true}}"
    local sync_count="${SYNC_COUNT:-${REPLICATION_SYNCHRONOUS_COUNT:-}}"
    local sync_replicas="${SYNC_REPLICAS:-${REPLICATION_SYNCHRONOUS_REPLICAS:-}}"
    
    if [[ "$sync_mode" != "true" ]]; then
        echo ""
        return 0
    fi
    
    if [[ -n "$sync_count" ]] && [[ -n "$sync_replicas" ]]; then
        echo "ANY ${sync_count} (${sync_replicas})"
    else
        echo "*"
    fi
}

backup_config() {
    local backup_file="${PGDATA}/postgresql.conf.backup.$(date +%Y%m%d%H%M%S)"
    cp "${PGDATA}/postgresql.conf" "$backup_file"
    log_info "Backed up current config to: $backup_file"
}

update_config() {
    local new_value="$1"
    local config_file="${PGDATA}/postgresql.conf"
    
    if [[ -z "$new_value" ]]; then
        if grep -q "synchronous_standby_names" "$config_file" 2>/dev/null; then
            sed -i '/^[[:space:]]*synchronous_standby_names[[:space:]]*=.*/d' "$config_file"
            log_info "Removed synchronous_standby_names (async mode enabled)"
        else
            log_info "synchronous_standby_names not present, already in async mode"
        fi
    else
        sed -i '/^[[:space:]]*synchronous_standby_names[[:space:]]*=.*/d' "$config_file"
        echo "synchronous_standby_names = '${new_value}'" >> "$config_file"
        log_info "Set synchronous_standby_names = '${new_value}'"
    fi
}

reload_postgres() {
    log_info "Reloading PostgreSQL configuration..."
    
    if ! su - postgres -c "${POSTGRES_BIN}/pg_ctl reload -D ${PGDATA}" 2>/dev/null; then
        if ! su - postgres -c "${POSTGRES_BIN}/pg_reload_conf" -D "${PGDATA}"; then
            log_error "Failed to reload PostgreSQL configuration"
            return 1
        fi
    fi
    
    log_info "PostgreSQL configuration reloaded successfully"
    return 0
}

main() {
    log_info "Starting synchronous replication config reload"
    
    parse_args "$@"
    
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    if [[ ! -f "${PGDATA}/postgresql.conf" ]]; then
        log_error "postgresql.conf not found at: ${PGDATA}/postgresql.conf"
        exit 1
    fi
    
    local new_ssn_value
    new_ssn_value=$(generate_ssn_value)
    
    backup_config
    update_config "$new_ssn_value"
    
    if ! reload_postgres; then
        log_error "Failed to reload configuration"
        exit 1
    fi
    
    log_info "Synchronous replication configuration reloaded successfully"
    log_info "Use 'SELECT client_addr, state, sync_state FROM pg_stat_replication;' to verify"
}

main "$@"
