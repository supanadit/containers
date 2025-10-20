#!/bin/bash
# 06-php-limits.sh - Configure PHP limits

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring PHP limits"

# Set PHP Memory Limit to PHP.ini
if [ -n "${PHP_MEMORY_LIMIT:-}" ]; then
    log_info "Setting PHP memory limit: $PHP_MEMORY_LIMIT"
    if [ -f /usr/local/lib/php.ini ]; then
        # Use AWK to replace existing memory_limit or add it if not found
        awk -v limit="$PHP_MEMORY_LIMIT" '
        BEGIN { found=0 }
        /^[[:space:]]*memory_limit[[:space:]]*=/ {
            print "memory_limit = " limit
            found=1
            next
        }
        {print}
        END {
            if (!found) print "memory_limit = " limit
        }
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    else
        # If php.ini doesn't exist, create it with memory_limit
        echo "memory_limit = $PHP_MEMORY_LIMIT" > /usr/local/lib/php.ini
    fi
fi

# Set PHP Upload Max Filesize to PHP.ini
if [ -n "${PHP_UPLOAD_MAX_FILESIZE:-}" ]; then
    log_info "Setting PHP upload max filesize: $PHP_UPLOAD_MAX_FILESIZE"
    if [ -f /usr/local/lib/php.ini ]; then
        awk -v limit="$PHP_UPLOAD_MAX_FILESIZE" '
        BEGIN { found=0 }
        /^[[:space:]]*upload_max_filesize[[:space:]]*=/ {
            print "upload_max_filesize = " limit
            found=1
            next
        }
        {print}
        END {
            if (!found) print "upload_max_filesize = " limit
        }
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    else
        echo "upload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE" >> /usr/local/lib/php.ini
    fi
fi

# Set PHP Post Max Size to PHP.ini
if [ -n "${PHP_POST_MAX_SIZE:-}" ]; then
    log_info "Setting PHP post max size: $PHP_POST_MAX_SIZE"
    if [ -f /usr/local/lib/php.ini ]; then
        awk -v limit="$PHP_POST_MAX_SIZE" '
        BEGIN { found=0 }
        /^[[:space:]]*post_max_size[[:space:]]*=/ {
            print "post_max_size = " limit
            found=1
            next
        }
        {print}
        END {
            if (!found) print "post_max_size = " limit
        }
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    else
        echo "post_max_size = $PHP_POST_MAX_SIZE" >> /usr/local/lib/php.ini
    fi
fi

log_info "PHP limits configuration completed"