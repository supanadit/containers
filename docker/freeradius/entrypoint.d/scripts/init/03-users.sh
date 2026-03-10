#!/bin/bash
# 03-users.sh - Handle user authentication configuration

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

main() {
    log_script_start "03-users.sh"
    
    local auth_type="${RADIUS_AUTH_TYPE:-files}"
    
    case "$auth_type" in
        files)
            configure_file_users
            ;;
        sql)
            configure_sql_users
            ;;
        ldap)
            configure_ldap_users
            ;;
        pam)
            configure_pam_users
            ;;
        *)
            log_error "Unknown auth type: $auth_type"
            return 1
            ;;
    esac
    
    log_script_end "03-users.sh"
}

configure_file_users() {
    log_info "Configuring file-based users"
    
    local users_file="/usr/local/freeradius/etc/raddb/users"
    local user_name="${FREERADIUS_USER_NAME:-admin}"
    local user_password="${FREERADIUS_USER_PASSWORD:-admin}"
    
    check_default_credentials
    
    if [[ -f "$users_file.original" ]]; then
        cp "$users_file.original" "$users_file"
        log_debug "Restored users file from original"
    fi
    
    if ! grep -q "^$user_name[[:space:]]" "$users_file" 2>/dev/null; then
        echo "$user_name Cleartext-Password := \"$user_password\"" >> "$users_file"
        log_info "Added default user: $user_name"
    else
        log_debug "Useruser_name already exists $ in users file"
    fi
    
    if [[ -n "${RADIUS_USERS:-}" ]]; then
        IFS=',' read -ra USERS <<< "$RADIUS_USERS"
        for user in "${USERS[@]}"; do
            user="$(echo "$user" | tr -d '[:space:]')"
            if [[ "$user" =~ ^([^:]+):(.+)$ ]]; then
                local username="${BASH_REMATCH[1]}"
                local password="${BASH_REMATCH[2]}"
                
                if ! grep -q "^$username[[:space:]]" "$users_file" 2>/dev/null; then
                    echo "$username Cleartext-Password := \"$password\"" >> "$users_file"
                    log_info "Added user from RADIUS_USERS: $username"
                else
                    log_debug "User $username already exists, skipping"
                fi
            fi
        done
    fi
    
    set_secure_permissions "$users_file"
    log_info "File-based users configured"
}

configure_sql_users() {
    log_info "Configuring SQL-based users"
    
    if [[ "${DB_ENABLE:-false}" != "true" ]]; then
        log_error "DB_ENABLE is not set to true"
        return 1
    fi
    
    local sql_conf="/usr/local/freeradius/etc/raddb/mods-available/sql"
    if [[ ! -f "$sql_conf" ]]; then
        log_error "SQL configuration not found. Set RADIUS_AUTH_TYPE to 'files' or configure DB_* variables"
        return 1
    fi
    
    local sites_enabled="/usr/local/freeradius/etc/raddb/sites-enabled"
    local default_site="$sites_enabled/default"
    
    if [[ -f "$default_site" ]]; then
        if ! grep -q '^[[:space:]]*sql' "$default_site"; then
            sed -i '/^[[:space:]]*authorize {/,/^[[:space:]]*}/ { /}/a\
        sql\
}' "$default_site"
        fi
        
        if ! grep -q '^[[:space:]]*sql' "$default_site"; then
            sed -i '/^[[:space:]]*accounting {/,/^[[:space:]]*}/ { /}/a\
        sql\
}' "$default_site"
        fi
        
        log_info "Enabled SQL in default site"
    fi
    
    local user_name="${FREERADIUS_USER_NAME:-admin}"
    local user_password="${FREERADIUS_USER_PASSWORD:-admin}"
    
    log_info "SQL-based authentication enabled"
    log_info "Default user '$user_name' will be created in database on first auth attempt"
    log_info "Or insert manually into radcheck table:"
    log_info "  INSERT INTO radcheck (username, attribute, op, value) VALUES ('\''$user_name'\'', 'Cleartext-Password', ':=', '\''$user_password'\'');"
    
    configure_file_users
}

configure_ldap_users() {
    log_info "Configuring LDAP-based users"
    
    if [[ "${LDAP_ENABLE:-false}" != "true" ]]; then
        log_error "LDAP_ENABLE is not set to true"
        return 1
    fi
    
    local ldap_conf="/usr/local/freeradius/etc/raddb/mods-available/ldap"
    if [[ ! -f "$ldap_conf" ]]; then
        log_error "LDAP configuration not found"
        return 1
    fi
    
    local sites_enabled="/usr/local/freeradius/etc/raddb/sites-enabled"
    local default_site="$sites_enabled/default"
    
    if [[ -f "$default_site" ]]; then
        if ! grep -q '^[[:space:]]*ldap' "$default_site"; then
            sed -i '/^[[:space:]]*authorize {/,/^[[:space:]]*}/ { /}/a\
        ldap\
}' "$default_site"
        fi
        log_info "Enabled LDAP in default site"
    fi
    
    log_info "LDAP-based authentication enabled"
    log_info "Users will be authenticated against LDAP server"
    
    configure_file_users
}

configure_pam_users() {
    log_info "Configuring PAM-based users"
    
    local pam_conf="/usr/local/freeradius/etc/raddb/mods-available/pam"
    local sites_enabled="/usr/local/freeradius/etc/raddb/sites-enabled"
    
    if [[ -f "$pam_conf" ]]; then
        local enabled_pam="$sites_enabled/pam"
        if [[ ! -e "$enabled_pam" ]]; then
            ln -sf "$pam_conf" "$enabled_pam"
            log_info "Enabled PAM module"
        fi
    fi
    
    if [[ -f "$sites_enabled/default" ]]; then
        if ! grep -q '^[[:space:]]*pam' "$sites_enabled/default"; then
            sed -i '/^[[:space:]]*authorize {/,/^[[:space:]]*}/ { /}/a\
        pam\
}' "$sites_enabled/default"
        fi
    fi
    
    log_info "PAM-based authentication enabled"
    log_info "Users will be authenticated against system accounts"
}

main "$@"
