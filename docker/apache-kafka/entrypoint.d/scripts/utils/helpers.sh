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

export -f is_truthy
export -f is_falsy
export -f normalize_bool
