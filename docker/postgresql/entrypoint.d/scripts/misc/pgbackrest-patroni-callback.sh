#!/bin/bash
# pgbackrest-patroni-callback.sh - Patroni callback script for pgBackRest
# Handles pgBackRest configuration updates on Patroni role changes
#
# Patroni calls this script with the following arguments:
#   on_start        - PostgreSQL is starting
#   on_stop         - PostgreSQL is stopping
#   on_role_change  - Role is changing (promote/demote)
#   post_backup     - Backup has completed
#   post_restore    - Restore has completed
#
# Usage in patroni.yml:
#   postgresql:
#       callbacks:
#           on_role_change: /usr/local/bin/pgbackrest-patroni-callback.sh on_role_change
#           post_backup: /usr/local/bin/pgbackrest-patroni-callback.sh post_backup
#           post_restore: /usr/local/bin/pgbackrest-patroni-callback.sh post_restore

set -euo pipefail

PATRONI_CALLBACK_ROLE="${1:-}"
PGBACKREST_CONFIG="${PGBACKREST_CONFIG:-/etc/pgbackrest.conf}"
PGBACKREST_STANZA="${PGBACKREST_STANZA:-default}"

log_info() {
    echo "[pgbackrest-patroni-callback] [INFO] $*"
}

log_error() {
    echo "[pgbackrest-patroni-callback] [ERROR] $*" >&2
}

log_warn() {
    echo "[pgbackrest-patroni-callback] [WARN] $*" >&2
}

is_truthy() {
    local value="${1:-}"
    case "${value,,}" in
        true | 1 | yes | on | y) return 0 ;;
        *) return 1 ;;
    esac
}

normalize_backup_standby() {
    local value="${1:-}"
    case "${value,,}" in
        y | yes | 1 | on | true)
            echo "y"
            ;;
        prefer)
            echo "prefer"
            ;;
        n | no | 0 | off | false)
            echo "n"
            ;;
        *)
            echo ""
            ;;
    esac
}

log_callback() {
    log_info "$*"
}

log_callback_error() {
    log_error "$*"
}

is_patroni_callback() {
    [ -n "${PATRONI_ROLE:-}" ] && [ -n "${PATRONI_SCOPE:-}" ]
}

regenerate_pgbackrest_config_for_primary() {
    log_callback "Node is becoming PRIMARY - regenerating pgBackRest config (removing pg2-host settings)"
    if [ -f "$PGBACKREST_CONFIG" ]; then
        local temp_config
        temp_config=$(mktemp)
        grep -v "^pg2-" "$PGBACKREST_CONFIG" > "$temp_config" || true
        grep -v "^backup-standby=" "$temp_config" > "${temp_config}.tmp" || true
        mv "${temp_config}.tmp" "$temp_config"
        if ! grep -q "^backup-standby=n" "$temp_config"; then
            echo "backup-standby=n" >> "$temp_config"
        fi
        mv "$temp_config" "$PGBACKREST_CONFIG"
        chmod 640 "$PGBACKREST_CONFIG"
        chown postgres:postgres "$PGBACKREST_CONFIG" 2>/dev/null || true
        log_callback "Removed pg2-host settings, set backup-standby=n for primary"
    fi
}

regenerate_pgbackrest_config_for_replica() {
    log_callback "Node is becoming REPLICA - regenerating pgBackRest config (adding pg2-host if configured)"
    if [ -f "$PGBACKREST_CONFIG" ] && [ -n "${PGBACKREST_PRIMARY_PATH:-}" ]; then
        local primary_host="${PGBACKREST_PRIMARY_HOST:-${PRIMARY_HOST:-}}"
        if [ -n "$primary_host" ]; then
            local temp_config
            temp_config=$(mktemp)
            grep -v "^pg2-" "$PGBACKREST_CONFIG" > "$temp_config" 2>/dev/null || cp "$PGBACKREST_CONFIG" "$temp_config"
            grep -v "^backup-standby=" "$temp_config" > "${temp_config}.tmp" 2>/dev/null || mv "$temp_config" "${temp_config}.tmp"
            temp_config="${temp_config}.tmp"
            local standby_mode
            standby_mode=$(normalize_backup_standby "${PGBACKREST_BACKUP_STANDBY:-}")
            [ -z "$standby_mode" ] && standby_mode="y"
            echo "backup-standby=${standby_mode}" >> "$temp_config"
            local primary_pg_port="${PGBACKREST_PRIMARY_PORT:-${PRIMARY_PORT:-5432}}"
            local primary_pg_user="${PGBACKREST_PRIMARY_USER:-${POSTGRES_USER:-postgres}}"
            local primary_ssh_port="${PGBACKREST_PRIMARY_SSH_PORT:-22}"
            local primary_ssh_user="${PGBACKREST_PRIMARY_SSH_USER:-postgres}"
            local primary_ssh_key="${PGBACKREST_PRIMARY_SSH_KEY_FILE:-/home/postgres/.ssh/id_rsa}"
            local primary_ssh_strict="${PGBACKREST_PRIMARY_SSH_STRICT_HOST_KEY_CHECKING:-yes}"
            echo "pg2-host=${primary_host}" >> "$temp_config"
            echo "pg2-host-port=${primary_pg_port}" >> "$temp_config"
            echo "pg2-host-user=${primary_pg_user}" >> "$temp_config"
            echo "pg2-port=${primary_pg_port}" >> "$temp_config"
            echo "pg2-user=${primary_pg_user}" >> "$temp_config"
            echo "pg2-host-key-file=${primary_ssh_key}" >> "$temp_config"
            if ! is_truthy "$primary_ssh_strict"; then
                echo "pg2-host-key-check-type=none" >> "$temp_config"
            fi
            mv "$temp_config" "$PGBACKREST_CONFIG"
            chmod 640 "$PGBACKREST_CONFIG"
            chown postgres:postgres "$PGBACKREST_CONFIG" 2>/dev/null || true
            log_callback "Added pg2-host settings for standby backup to primary ${primary_host}"
        else
            log_callback "PGBACKREST_PRIMARY_PATH set but no primary host configured, skipping pg2-host"
        fi
    fi
}

handle_on_role_change() {
    local new_role="$1"
    local old_role="${PATRONI_ROLE:-unknown}"
    log_callback "on_role_change: new_role=${new_role}, old_role=${old_role}"
    case "$new_role" in
        promote)
            regenerate_pgbackrest_config_for_primary
            log_callback "Promoted to primary - pgBackRest reconfigured"
            ;;
        demote)
            regenerate_pgbackrest_config_for_replica
            log_callback "Demoted to replica - pgBackRest reconfigured"
            ;;
        *)
            log_callback "Unknown role change: $new_role"
            ;;
    esac
}

handle_post_backup() {
    local backup_status="${PATRONI_BACKUP_STATUS:-success}"
    log_callback "post_backup: status=${backup_status}"
    if [ "$backup_status" = "success" ]; then
        log_callback "Backup completed successfully"
    else
        log_callback_error "Backup failed with status: $backup_status"
    fi
}

handle_post_restore() {
    log_callback "post_restore: Node has completed restore"
    local role="${PATRONI_ROLE:-}"
    if [ "$role" = "master" ] || [ "$role" = "primary" ]; then
        regenerate_pgbackrest_config_for_primary
    else
        regenerate_pgbackrest_config_for_replica
    fi
    log_callback "Post-restore pgBackRest reconfiguration complete"
}

main() {
    if ! is_truthy "${PGBACKREST_ENABLE:-false}"; then
        exit 0
    fi

    if ! is_patroni_callback; then
        log_callback "Not running as Patroni callback, skipping"
        exit 0
    fi

    log_callback "Called with action: ${PATRONI_CALLBACK_ROLE:-unknown}"

    case "${PATRONI_CALLBACK_ROLE}" in
        on_role_change)
            local new_role="${PATRONI_NEW_ROLE:-}"
            if [ -z "$new_role" ]; then
                log_callback_error "on_role_change called without PATRONI_NEW_ROLE"
                exit 1
            fi
            handle_on_role_change "$new_role"
            ;;
        post_backup)
            handle_post_backup
            ;;
        post_restore)
            handle_post_restore
            ;;
        on_start)
            log_callback "on_start: PostgreSQL starting"
            ;;
        on_stop)
            log_callback "on_stop: PostgreSQL stopping"
            ;;
        *)
            log_callback "Unhandled callback: ${PATRONI_CALLBACK_ROLE}"
            ;;
    esac

    exit 0
}

main "$@"
