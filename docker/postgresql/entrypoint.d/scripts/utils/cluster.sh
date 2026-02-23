#!/bin/bash
# cluster.sh - Cluster role helper utilities

# This script is sourced by other entrypoint scripts after logging utilities.
# It provides shared helpers for determining node roles across Patroni, native
# replication so that pgBackRest orchestration behaves
# consistently.

# Determine whether this node should be considered the primary/leader.
is_primary_role() {
    log_debug "Determining if node is primary"

    # Patroni-managed cluster: rely on Patroni REST API when available.
    if [ "${PATRONI_ENABLE:-false}" = "true" ]; then
        if command -v curl >/dev/null 2>&1; then
            local rest_base="${PATRONI_REST_URL:-http://localhost:8008}"
            if curl -sf "${rest_base}/master" >/dev/null 2>&1; then
                log_debug "Patroni REST /master endpoint reachable; node is primary"
                return 0
            fi
            local leader_payload
            if leader_payload=$(curl -sf "${rest_base}/leader" 2>/dev/null); then
                if echo "$leader_payload" | grep -qi '"role"[[:space:]]*:[[:space:]]*"leader"'; then
                    log_debug "Patroni REST reports leader role"
                    return 0
                fi
            fi
            log_debug "Patroni REST indicates this node is not the leader"
        else
            log_warn "curl not available; falling back to pg_is_in_recovery() for Patroni primary check"
        fi
    fi

    # Citus-managed cluster: check role if Patroni not enabled
    if [ "${CITUS_ENABLE:-false}" = "true" ] && [ "${PATRONI_ENABLE:-false}" != "true" ]; then
        if [ "${CITUS_ROLE:-}" = "coordinator" ]; then
            log_debug "Citus coordinator role; node is primary"
            return 0
        elif [ "${CITUS_ROLE:-}" = "worker" ]; then
            log_debug "Citus worker role; node is replica"
            return 1
        fi
    fi

    # Fallback: rely on PostgreSQL recovery state.
    if command -v psql >/dev/null 2>&1; then
        local result
        local host="${POSTGRES_HOST:-localhost}"
        if result=$(PGPASSWORD="${POSTGRES_PASSWORD:-}" \
            psql -qtAX -U "${POSTGRES_USER:-postgres}" -h "$host" -p "${POSTGRESQL_PORT:-5432}" \
                -d "${POSTGRES_DB:-postgres}" -c "select pg_is_in_recovery();" 2>/dev/null); then
            if echo "$result" | grep -Eq '^f'; then
                log_debug "pg_is_in_recovery() returned false; node is primary"
                return 0
            fi
        fi
    fi

    log_debug "Primary role check failed or indicates replica"
    return 1
}
export -f is_primary_role

# Determine the pgBackRest backup mode for this node
# Returns: "primary" | "standby-ssh" | "standby-skip" | "disabled"
#
# Backup Strategy:
# - Primary nodes: return "primary" (create stanza, run backups)
# - Replica with SSH configured (PGBACKREST_PRIMARY_PATH set):
#   -> return "standby-ssh" (uses backup-standby=y with pg2-* SSH connection)
# - Replica without SSH:
#   -> return "standby-skip" (skip backup entirely; primary handles it or backup is disabled)
# - Backup not enabled: return "disabled"
#
# Note: pgBackRest cannot create a stanza on a replica without primary access.
# Therefore, replica backups REQUIRE SSH configuration to coordinate with primary.
# Replicas without SSH will skip backup operations silently.
determine_pgbackrest_mode() {
    # Check if backup is enabled
    if [ "${PGBACKREST_ENABLE:-false}" != "true" ]; then
        echo "disabled"
        return 0
    fi

    # Check if this is a primary node
    if is_primary_role; then
        echo "primary"
        return 0
    fi

    # This is a replica - check if SSH is configured for standby backup
    # pgBackRest cannot create stanzas on replicas without primary access,
    # so SSH configuration is REQUIRED for any replica backup operations.
    if [ -n "${PGBACKREST_PRIMARY_PATH:-}" ]; then
        # SSH mode configured - can do standby backup
        log_debug "Replica with SSH configured (PGBACKREST_PRIMARY_PATH set)"
        echo "standby-ssh"
        return 0
    fi

    # No SSH configured - replica cannot perform backup operations
    log_debug "Replica without SSH; backup operations skipped"
    echo "standby-skip"
    return 0
}
export -f determine_pgbackrest_mode

# Check if primary host is accessible for standby backup coordination
is_primary_accessible() {
    local primary_host="${PRIMARY_HOST:-}"
    local primary_port="${PRIMARY_PORT:-5432}"
    
    if [ -z "$primary_host" ]; then
        log_debug "PRIMARY_HOST not set; primary not accessible"
        return 1
    fi
    
    # Try TCP connection to primary PostgreSQL port
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$primary_host" "$primary_port" 2>/dev/null; then
            log_debug "Primary accessible at $primary_host:$primary_port"
            return 0
        fi
    elif command -v timeout >/dev/null 2>&1; then
        if timeout 3 bash -c "echo >/dev/tcp/$primary_host/$primary_port" 2>/dev/null; then
            log_debug "Primary accessible at $primary_host:$primary_port"
            return 0
        fi
    fi
    
    # Try pg_isready as fallback
    if command -v pg_isready >/dev/null 2>&1; then
        if pg_isready -h "$primary_host" -p "$primary_port" -t 3 >/dev/null 2>&1; then
            log_debug "Primary accessible via pg_isready at $primary_host:$primary_port"
            return 0
        fi
    fi
    
    log_debug "Primary not accessible at $primary_host:$primary_port"
    return 1
}
export -f is_primary_accessible