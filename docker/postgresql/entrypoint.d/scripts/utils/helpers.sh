#!/bin/bash
# helpers.sh - Shared utility functions for boolean handling and validation
# Provides consistent truthy/falsy evaluation across all container scripts

is_truthy() {
    local value="${1:-}"
    case "${value,,}" in
        true | 1 | yes | on | y) return 0 ;;
        *) return 1 ;;
    esac
}

is_falsy() {
    ! is_truthy "$1"
}

assert_pgbackrest_enabled() {
    local feature_name="$1"
    if ! is_truthy "${PGBACKREST_ENABLE:-false}"; then
        log_warn "[${feature_name}] PGBACKREST_ENABLE is not true; ${feature_name} will be disabled"
        return 1
    fi
    return 0
}

normalize_bool() {
    local value="${1:-}"
    case "${value,,}" in
        true | 1 | yes | on)
            echo "true"
            ;;
        false | 0 | no | off)
            echo "false"
            ;;
        *)
            echo ""
            ;;
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

export -f is_truthy
export -f is_falsy
export -f assert_pgbackrest_enabled
export -f normalize_bool
export -f normalize_backup_standby