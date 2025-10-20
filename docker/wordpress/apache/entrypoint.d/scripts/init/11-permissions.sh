#!/bin/bash
# 11-permissions.sh - Set file and directory permissions

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Setting file and directory permissions"

# Custom Stateless .php copy
if [ "${IS_STATELESS:-false}" = "true" ]; then
    log_info "Processing stateless file copies"
    # Handle STATELESS_FILE_<name>
    for var in $(compgen -A variable | grep '^STATELESS_FILE_'); do
        # Check if the variable is valid
        # For example STATELESS_FILE_OBJECT_CACHE: object-cache.php
        # It will copy /content/stateless/object-cache.php to /var/www/html/wp-content/object-cache.php
        # But first it will check /content/stateless/object-cache.php exist, if not it will skipped
        var_name=${var#STATELESS_FILE_}
        var_value="${!var}"
        if [ -f "/content/stateless/${var_value}" ]; then
            log_info "Copying stateless file: $var_value"
            cp "/content/stateless/${var_value}" "/var/www/html/wp-content/"
            chown www-data:www-data "/var/www/html/wp-content/${var_value}"
        else
            log_info "Stateless file not found, skipping: $var_value"
        fi
    done
fi

log_info "Setting WordPress directory permissions"

# Function to ensure directory exists and has correct permissions
ensure_wp_directory() {
    local dir="$1"
    local target_dir="$dir"

    # If wp-content is a symlink, work with the target
    if [ -L "/var/www/html/wp-content" ]; then
        local link_target
        link_target=$(readlink -f "/var/www/html/wp-content")
        if [[ "$dir" == /var/www/html/wp-content* ]]; then
            target_dir="${link_target}${dir#/var/www/html/wp-content}"
        fi
    fi

    # Create directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Set permissions on the target directory
    if [ -d "$target_dir" ]; then
        chmod 775 "$target_dir"
        chown www-data:www-data "$target_dir"
        log_info "Set permissions on: $target_dir"
    fi

    # Also set permissions on the symlink path if it's different
    if [ "$target_dir" != "$dir" ] && [ -d "$dir" ]; then
        chmod 775 "$dir"
        chown www-data:www-data "$dir"
        log_info "Set permissions on symlink: $dir"
    fi
}

# Ensure WordPress content directories exist and have proper permissions
WP_DIRS=(
    "/var/www/html/wp-content"
    "/var/www/html/wp-content/uploads"
    "/var/www/html/wp-content/plugins"
    "/var/www/html/wp-content/themes"
    "/var/www/html/wp-content/fonts"
)

for dir in "${WP_DIRS[@]}"; do
    ensure_wp_directory "$dir"
done

# Set permissions for main WordPress directory
chmod 755 /var/www/html
chown www-data:www-data /var/www/html

# Ensure wp-config.php has correct permissions if it exists
if [ -f "/var/www/html/wp-config.php" ]; then
    chown www-data:www-data /var/www/html/wp-config.php
    chmod 644 /var/www/html/wp-config.php
fi

# Final permission fix - ensure all wp-content files are accessible
if [ -d "/var/www/html/wp-content" ]; then
    find /var/www/html/wp-content -type d -exec chmod 775 {} \; 2>/dev/null || true
    find /var/www/html/wp-content -type f -exec chmod 664 {} \; 2>/dev/null || true
    chown -R www-data:www-data /var/www/html/wp-content 2>/dev/null || true
fi

log_info "Permissions configuration completed"