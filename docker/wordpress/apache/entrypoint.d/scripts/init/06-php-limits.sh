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

# Set PHP Max Execution Time to PHP.ini
if [ -n "${PHP_MAX_EXECUTION_TIME:-}" ]; then
    log_info "Setting PHP max execution time: $PHP_MAX_EXECUTION_TIME"
    if [ -f /usr/local/lib/php.ini ]; then
        awk -v limit="$PHP_MAX_EXECUTION_TIME" '
        BEGIN { found=0 }
        /^[[:space:]]*max_execution_time[[:space:]]*=/ {
            print "max_execution_time = " limit
            found=1
            next
        }
        {print}
        END {
            if (!found) print "max_execution_time = " limit
        }
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    else
        echo "max_execution_time = $PHP_MAX_EXECUTION_TIME" >> /usr/local/lib/php.ini
    fi
fi

# Set PHP Max Input Time to PHP.ini
if [ -n "${PHP_MAX_INPUT_TIME:-}" ]; then
    log_info "Setting PHP max input time: $PHP_MAX_INPUT_TIME"
    if [ -f /usr/local/lib/php.ini ]; then
        awk -v limit="$PHP_MAX_INPUT_TIME" '
        BEGIN { found=0 }
        /^[[:space:]]*max_input_time[[:space:]]*=/ {
            print "max_input_time = " limit
            found=1
            next
        }
        {print}
        END {
            if (!found) print "max_input_time = " limit
        }
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    else
        echo "max_input_time = $PHP_MAX_INPUT_TIME" >> /usr/local/lib/php.ini
    fi
fi

# Configure OPcache
log_info "Configuring PHP OPcache"

# Enable or disable OPcache
if [ "${PHP_OPCACHE_ENABLE:-true}" = "false" ]; then
    log_info "Disabling PHP OPcache"
    if [ -f /usr/local/lib/php.ini ]; then
        awk '
        /^[[:space:]]*;?zend_extension[[:space:]]*=.*opcache/ {
            print "; " $0
            next
        }
        /^[[:space:]]*opcache\.enable/ {
            print "opcache.enable = 0"
            next
        }
        {print}
        ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
    fi
else
    log_info "Enabling PHP OPcache"

    # Set OPcache memory consumption
    if [ -n "${PHP_OPCACHE_MEMORY:-}" ]; then
        log_info "Setting OPcache memory: ${PHP_OPCACHE_MEMORY}MB"
        if [ -f /usr/local/lib/php.ini ]; then
            awk -v mem="$PHP_OPCACHE_MEMORY" '
            BEGIN { found=0 }
            /^[[:space:]]*;?opcache\.memory_consumption[[:space:]]*=/ {
                print "opcache.memory_consumption = " mem
                found=1
                next
            }
            {print}
            END {
                if (!found) print "opcache.memory_consumption = " mem
            }
            ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
        fi
    fi

    # Set OPcache max accelerated files
    if [ -n "${PHP_OPCACHE_MAX_ACCELERATED_FILES:-}" ]; then
        log_info "Setting OPcache max accelerated files: ${PHP_OPCACHE_MAX_ACCELERATED_FILES}"
        if [ -f /usr/local/lib/php.ini ]; then
            awk -v files="$PHP_OPCACHE_MAX_ACCELERATED_FILES" '
            BEGIN { found=0 }
            /^[[:space:]]*;?opcache\.max_accelerated_files[[:space:]]*=/ {
                print "opcache.max_accelerated_files = " files
                found=1
                next
            }
            {print}
            END {
                if (!found) print "opcache.max_accelerated_files = " files
            }
            ' /usr/local/lib/php.ini > /usr/local/lib/php.ini.tmp && mv /usr/local/lib/php.ini.tmp /usr/local/lib/php.ini
        fi
    fi
fi

log_info "PHP limits configuration completed"