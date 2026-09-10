#!/bin/bash
# startup.sh - Start the WordPress application

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Starting WordPress application"

# Final permission check and fix before starting Apache
log_info "Performing final permission check"

# Verify Apache user configuration
log_info "Verifying Apache user configuration"
if ! id -u www-data >/dev/null 2>&1; then
    log_error "www-data user does not exist - creating it"
    groupadd -r www-data 2>/dev/null || true
    useradd -r -g www-data www-data 2>/dev/null || true
fi

# Check if Apache config has correct user
if grep -q "User www-data" /usr/local/apache2/conf/httpd.conf; then
    log_info "Apache configured to run as www-data user"
else
    log_warn "Apache user not configured correctly"
fi

# Ensure the symlink is properly set up for stateful mode
if [ "${IS_STATELESS:-false}" = "false" ]; then
    log_info "Ensuring stateful mode symlink is correct"
    
    # Create backward-compatible /content symlink to /opt/containers/data
    if [ ! -L "/content" ] && [ ! -d "/content" ]; then
        ln -s /opt/containers/data /content
        log_info "Created backward-compatible /content symlink to /opt/containers/data"
    fi
    
    # Check if wp-content symlink exists and points to the right place
    if [ -L "/var/www/html/wp-content" ]; then
        link_target=$(readlink -f "/var/www/html/wp-content")
        if [ "$link_target" != "/opt/containers/data/wp-content" ]; then
            log_warn "wp-content symlink points to wrong location: $link_target"
            # Remove incorrect symlink and create correct one
            rm -f /var/www/html/wp-content
            ln -s /opt/containers/data/wp-content /var/www/html/wp-content
            log_info "Recreated wp-content symlink to /opt/containers/data/wp-content"
        fi
    else
        log_warn "wp-content symlink missing, recreating"
        # Remove if it's a directory and create symlink
        if [ -d "/var/www/html/wp-content" ]; then
            rm -rf /var/www/html/wp-content
        fi
        ln -s /opt/containers/data/wp-content /var/www/html/wp-content
        log_info "Created wp-content symlink to /opt/containers/data/wp-content"
    fi
fi

# Handle stateless file copies that might need to be done after volume mount
if [ "${IS_STATELESS:-false}" = "true" ]; then
    log_info "Processing any remaining stateless file copies"
    # Handle STATELESS_FILE_<name> - check again in case volume mount made files available
    for var in $(compgen -A variable | grep '^STATELESS_FILE_'); do
        var_name=${var#STATELESS_FILE_}
        var_value="${!var}"
        if [ -f "/opt/containers/data/stateless/${var_value}" ] && [ ! -f "/var/www/html/wp-content/${var_value}" ]; then
            log_info "Copying stateless file: $var_value"
            cp "/opt/containers/data/stateless/${var_value}" "/var/www/html/wp-content/"
            chown www-data:www-data "/var/www/html/wp-content/${var_value}" 2>/dev/null || true
        fi
    done
fi

# Force create all required WordPress directories with correct permissions
log_info "Ensuring all WordPress directories exist and have correct permissions"

# For stateful mode, create directories on the mounted volume first
if [ "${IS_STATELESS:-false}" = "false" ]; then
    MOUNTED_REQUIRED_DIRS=(
        "/opt/containers/data/wp-content/uploads"
        "/opt/containers/data/wp-content/uploads/fonts"
        "/opt/containers/data/wp-content/plugins"
        "/opt/containers/data/wp-content/themes"
        "/opt/containers/data/wp-content/upgrade"
    )
    
    for dir in "${MOUNTED_REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log_info "Creating directory on mounted volume: $dir"
            mkdir -p "$dir" 2>/dev/null || log_warn "Failed to create directory: $dir"
        fi
    done
fi

# Create directories in the expected locations (through symlink)
WP_REQUIRED_DIRS=(
    "/var/www/html/wp-content"
    "/var/www/html/wp-content/uploads"
    "/var/www/html/wp-content/uploads/fonts"
    "/var/www/html/wp-content/plugins"
    "/var/www/html/wp-content/themes"
    "/var/www/html/wp-content/upgrade"
)

for dir in "${WP_REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log_info "Creating required directory: $dir"
        mkdir -p "$dir" 2>/dev/null || log_warn "Failed to create directory: $dir"
    fi
done

# Set aggressive permissions - try multiple approaches
log_info "Setting comprehensive permissions for WordPress directories"

# For the main WordPress directory
chmod 755 /var/www/html 2>/dev/null || true
chown www-data:www-data /var/www/html 2>/dev/null || true

# Debug: Check symlink status
log_info "Checking symlink status..."
if [ -L "/var/www/html/wp-content" ]; then
    link_target=$(readlink -f "/var/www/html/wp-content")
    log_info "wp-content symlink exists, target: $link_target"
    ls -la /var/www/html/wp-content 2>/dev/null || log_warn "Cannot list symlink"
else
    log_warn "wp-content is not a symlink!"
    ls -la /var/www/html/wp-content 2>/dev/null || log_warn "Cannot list wp-content"
fi

# Set permissions on wp-content - optimized for large directories
if [ "${SKIP_PERMISSIONS:-false}" != "true" ]; then
    if [ -d "/opt/containers/data/wp-content" ]; then
        log_info "Setting permissions on mounted volume /opt/containers/data/wp-content (optimized)"
        
        # Only set ownership/permissions on the top-level directories, not every file
        # This is much faster for large wp-content directories
        chown www-data:www-data /opt/containers/data/wp-content 2>/dev/null || log_warn "chown failed on wp-content root"
        chmod 775 /opt/containers/data/wp-content 2>/dev/null || log_warn "chmod failed on wp-content root"
        
        # Set permissions on main subdirectories only
        for subdir in uploads plugins themes upgrade; do
            if [ -d "/opt/containers/data/wp-content/$subdir" ]; then
                chown www-data:www-data "/opt/containers/data/wp-content/$subdir" 2>/dev/null || true
                chmod 775 "/opt/containers/data/wp-content/$subdir" 2>/dev/null || true
            fi
        done
        
        # Special check for fonts directory - ensure it exists and has proper permissions
        if [ ! -d "/opt/containers/data/wp-content/uploads/fonts" ]; then
            log_info "Creating fonts directory on mounted volume"
            mkdir -p /opt/containers/data/wp-content/uploads/fonts 2>/dev/null || log_warn "Failed to create fonts directory"
        fi
        if [ -d "/opt/containers/data/wp-content/uploads/fonts" ]; then
            chown www-data:www-data /opt/containers/data/wp-content/uploads/fonts 2>/dev/null || true
            chmod 775 /opt/containers/data/wp-content/uploads/fonts 2>/dev/null || true
        fi
        
        log_info "Permissions set successfully (skipped recursive traversal for performance)"
    elif [ -d "/var/www/html/wp-content" ]; then
        # Fallback for stateless mode or if /opt/containers/data doesn't exist
        log_info "Setting permissions on wp-content directory"
        chown www-data:www-data /var/www/html/wp-content 2>/dev/null || log_warn "chown failed"
        chmod 775 /var/www/html/wp-content 2>/dev/null || log_warn "chmod failed"
    fi
else
    log_info "Skipping permission changes (SKIP_PERMISSIONS=true)"
fi

# Ensure the /opt/containers/data directory itself has proper permissions
if [ -d "/opt/containers/data" ]; then
    log_info "Setting permissions on /opt/containers/data mount point"
    chmod 755 /opt/containers/data 2>/dev/null || log_warn "Cannot set permissions on /opt/containers/data"
    chown www-data:www-data /opt/containers/data 2>/dev/null || log_warn "Cannot chown /opt/containers/data"
fi

# Ensure the main directory is accessible
if [ ! -w "/var/www/html" ]; then
    log_warn "Main WordPress directory is not writable, attempting to fix"
    # Try to make it writable by group if chown fails
    chmod 775 /var/www/html 2>/dev/null || true
    chmod g+w /var/www/html 2>/dev/null || true
fi

# Execute the main command (typically Apache)
exec "$@"