#!/bin/bash
# cluster.sh - Cluster role helper utilities

# This script is sourced by other entrypoint scripts after logging utilities.
# It provides shared helpers for determining node roles across Patroni, native
# replication, and Citus deployments so that pgBackRest orchestration behaves
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

# Determine whether backups should run on this node in a Citus deployment.
is_citus_backup_allowed() {
    if [ "${CITUS_ENABLE:-false}" != "true" ]; then
        return 0
    fi

    local scope="${CITUS_BACKUP_SCOPE:-coordinator-only}"
    case "$scope" in
        coordinator-only)
            if [ "${CITUS_ROLE:-coordinator}" != "coordinator" ]; then
                log_debug "Citus backup scope restricted to coordinator; skipping on role=${CITUS_ROLE:-unknown}"
                return 1
            fi
            ;;
        all-nodes)
            log_debug "Citus backup scope set to all nodes"
            ;;
        *)
            log_warn "Unknown CITUS_BACKUP_SCOPE='${scope}', defaulting to coordinator-only behavior"
            if [ "${CITUS_ROLE:-coordinator}" != "coordinator" ]; then
                return 1
            fi
            ;;
    esac

    return 0
}
export -f is_citus_backup_allowed
