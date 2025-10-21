#!/bin/bash
# 07-apache-mpm.sh - Configure Apache MPM

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Configuring Apache MPM"

# Choose Apache MPM: https://www.datadoghq.com/blog/monitoring-apache-web-server-performance
APACHE_MPM=${APACHE_MPM:-event} # default to event if not set

log_info "Setting Apache MPM to: $APACHE_MPM"

if [ "$APACHE_MPM" = "prefork" ]; then
    sed -i 's/^LoadModule mpm_event_module/#LoadModule mpm_event_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^LoadModule mpm_worker_module/#LoadModule mpm_worker_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^#LoadModule mpm_prefork_module/LoadModule mpm_prefork_module/' /usr/local/apache2/conf/httpd.conf
elif [ "$APACHE_MPM" = "worker" ]; then
    sed -i 's/^LoadModule mpm_event_module/#LoadModule mpm_event_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^#LoadModule mpm_worker_module/LoadModule mpm_worker_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^LoadModule mpm_prefork_module/#LoadModule mpm_prefork_module/' /usr/local/apache2/conf/httpd.conf
else # event
    sed -i 's/^#LoadModule mpm_event_module/LoadModule mpm_event_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^LoadModule mpm_worker_module/#LoadModule mpm_worker_module/' /usr/local/apache2/conf/httpd.conf
    sed -i 's/^LoadModule mpm_prefork_module/#LoadModule mpm_prefork_module/' /usr/local/apache2/conf/httpd.conf
fi

# APACHE_INCLUDE_CONFIG_MPM is true, it will include extra MPM config
if [ "${APACHE_INCLUDE_CONFIG_MPM:-false}" = "true" ]; then
    log_info "Including MPM configuration file"
    # It will uncomment "Include conf/extra/httpd-mpm.conf" in httpd.conf use AWK
    if ! grep -q "^Include conf/extra/httpd-mpm.conf" /usr/local/apache2/conf/httpd.conf; then
        awk '
        BEGIN { found=0 }
        /^#Include[[:space:]]+conf\/extra\/httpd-mpm.conf/ {
            print "Include conf/extra/httpd-mpm.conf"
            found=1
            next
        }
        {print}
        END {
            if (!found) print "#Include conf/extra/httpd-mpm.conf"
        }
        ' /usr/local/apache2/conf/httpd.conf > /usr/local/apache2/conf/httpd.conf.tmp && mv /usr/local/apache2/conf/httpd.conf.tmp /usr/local/apache2/conf/httpd.conf
    fi
fi

# Custom Prefork Apache MPM configuration
# APACHE_CUSTOM_MPM_PREFORK is true, it will add custom config to /usr/local/apache2/conf/httpd.conf
if [ "${APACHE_CUSTOM_MPM_PREFORK:-false}" = "true" ] && [ "$APACHE_MPM" = "prefork" ] && [ "${APACHE_INCLUDE_CONFIG_MPM:-false}" = "true" ]; then
    log_info "Configuring custom Prefork MPM settings"
    # We will set custom env by default
    APACHE_MPM_PREFORK_START_SERVERS=${APACHE_MPM_PREFORK_START_SERVERS:-5}
    APACHE_MPM_PREFORK_MIN_SPARE_SERVERS=${APACHE_MPM_PREFORK_MIN_SPARE_SERVERS:-5}
    APACHE_MPM_PREFORK_MAX_SPARE_SERVERS=${APACHE_MPM_PREFORK_MAX_SPARE_SERVERS:-10}
    APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS=${APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS:-250}
    APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD=${APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD:-0}

    # MPM Prefork Configuration we will modify it using AWK
    awk -v start="$APACHE_MPM_PREFORK_START_SERVERS" -v min="$APACHE_MPM_PREFORK_MIN_SPARE_SERVERS" \
    -v max="$APACHE_MPM_PREFORK_MAX_SPARE_SERVERS" -v max_workers="$APACHE_MPM_PREFORK_MAX_REQUEST_WORKERS" \
    -v max_requests="$APACHE_MPM_PREFORK_MAX_REQUESTS_PER_CHILD" '
    BEGIN { in_block=0; block_found=0 }
    /^<IfModule mpm_prefork_module>/ {
        print
        print "    StartServers " start
        print "    MinSpareServers " min
        print "    MaxSpareServers " max
        print "    MaxRequestWorkers " max_workers
        print "    MaxConnectionsPerChild " max_requests
        in_block=1
        block_found=1
        next
    }
    /^<\/IfModule>/ {
        print
        in_block=0
        next
    }
    in_block && /^[[:space:]]*(StartServers|MinSpareServers|MaxSpareServers|MaxRequestWorkers|MaxConnectionsPerChild)[[:space:]]/ {
        next
    }
    { print }
    END {
        if (!block_found) {
            print "<IfModule mpm_prefork_module>"
            print "    StartServers " start
            print "    MinSpareServers " min
            print "    MaxSpareServers " max
            print "    MaxRequestWorkers " max_workers
            print "    MaxConnectionsPerChild " max_requests
            print "</IfModule>"
        }
    }
    ' /usr/local/apache2/conf/extra/httpd-mpm.conf > /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp && mv /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp /usr/local/apache2/conf/extra/httpd-mpm.conf
fi

# Custom Event Apache MPM configuration
if [ "${APACHE_CUSTOM_MPM_EVENT:-false}" = "true" ] && [ "$APACHE_MPM" = "event" ] && [ "${APACHE_INCLUDE_CONFIG_MPM:-false}" = "true" ]; then
    log_info "Configuring custom Event MPM settings"
    APACHE_MPM_EVENT_START_SERVERS=${APACHE_MPM_EVENT_START_SERVERS:-3}
    APACHE_MPM_EVENT_MIN_SPARE_THREADS=${APACHE_MPM_EVENT_MIN_SPARE_THREADS:-75}
    APACHE_MPM_EVENT_MAX_SPARE_THREADS=${APACHE_MPM_EVENT_MAX_SPARE_THREADS:-250}
    APACHE_MPM_EVENT_THREADS_PER_CHILD=${APACHE_MPM_EVENT_THREADS_PER_CHILD:-25}
    APACHE_MPM_EVENT_MAX_REQUEST_WORKERS=${APACHE_MPM_EVENT_MAX_REQUEST_WORKERS:-400}
    APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD=${APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD:-0}

    awk -v start="$APACHE_MPM_EVENT_START_SERVERS" \
        -v min="$APACHE_MPM_EVENT_MIN_SPARE_THREADS" \
        -v max="$APACHE_MPM_EVENT_MAX_SPARE_THREADS" \
        -v threads="$APACHE_MPM_EVENT_THREADS_PER_CHILD" \
        -v max_workers="$APACHE_MPM_EVENT_MAX_REQUEST_WORKERS" \
        -v max_connections="$APACHE_MPM_EVENT_MAX_CONNECTIONS_PER_CHILD" '
    BEGIN { in_block=0; block_found=0 }
    /^<IfModule mpm_event_module>/ {
        print
        print "    StartServers " start
        print "    MinSpareThreads " min
        print "    MaxSpareThreads " max
        print "    ThreadsPerChild " threads
        print "    MaxRequestWorkers " max_workers
        print "    MaxConnectionsPerChild " max_connections
        in_block=1
        block_found=1
        next
    }
    /^<\/IfModule>/ {
        print
        in_block=0
        next
    }
    in_block && /^[[:space:]]*(StartServers|MinSpareThreads|MaxSpareThreads|ThreadsPerChild|MaxRequestWorkers|MaxConnectionsPerChild)[[:space:]]/ {
        next
    }
    { print }
    END {
        if (!block_found) {
            print "<IfModule mpm_event_module>"
            print "    StartServers " start
            print "    MinSpareThreads " min
            print "    MaxSpareThreads " max
            print "    ThreadsPerChild " threads
            print "    MaxRequestWorkers " max_workers
            print "    MaxConnectionsPerChild " max_connections
            print "</IfModule>"
        }
    }
    ' /usr/local/apache2/conf/extra/httpd-mpm.conf > /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp && mv /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp /usr/local/apache2/conf/extra/httpd-mpm.conf
fi

# Custom Worker Apache MPM configuration
if [ "${APACHE_CUSTOM_MPM_WORKER:-false}" = "true" ] && [ "$APACHE_MPM" = "worker" ] && [ "${APACHE_INCLUDE_CONFIG_MPM:-false}" = "true" ]; then
    log_info "Configuring custom Worker MPM settings"
    APACHE_MPM_WORKER_START_SERVERS=${APACHE_MPM_WORKER_START_SERVERS:-3}
    APACHE_MPM_WORKER_MIN_SPARE_THREADS=${APACHE_MPM_WORKER_MIN_SPARE_THREADS:-75}
    APACHE_MPM_WORKER_MAX_SPARE_THREADS=${APACHE_MPM_WORKER_MAX_SPARE_THREADS:-250}
    APACHE_MPM_WORKER_THREADS_PER_CHILD=${APACHE_MPM_WORKER_THREADS_PER_CHILD:-25}
    APACHE_MPM_WORKER_MAX_REQUEST_WORKERS=${APACHE_MPM_WORKER_MAX_REQUEST_WORKERS:-400}
    APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD=${APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD:-0}

    awk -v start="$APACHE_MPM_WORKER_START_SERVERS" \
        -v min="$APACHE_MPM_WORKER_MIN_SPARE_THREADS" \
        -v max="$APACHE_MPM_WORKER_MAX_SPARE_THREADS" \
        -v threads="$APACHE_MPM_WORKER_THREADS_PER_CHILD" \
        -v max_workers="$APACHE_MPM_WORKER_MAX_REQUEST_WORKERS" \
        -v max_connections="$APACHE_MPM_WORKER_MAX_CONNECTIONS_PER_CHILD" '
    BEGIN { in_block=0; block_found=0 }
    /^<IfModule mpm_worker_module>/ {
        print
        print "    StartServers " start
        print "    MinSpareThreads " min
        print "    MaxSpareThreads " max
        print "    ThreadsPerChild " threads
        print "    MaxRequestWorkers " max_workers
        print "    MaxConnectionsPerChild " max_connections
        in_block=1
        block_found=1
        next
    }
    /^<\/IfModule>/ {
        print
        in_block=0
        next
    }
    in_block && /^[[:space:]]*(StartServers|MinSpareThreads|MaxSpareThreads|ThreadsPerChild|MaxRequestWorkers|MaxConnectionsPerChild)[[:space:]]/ {
        next
    }
    { print }
    END {
        if (!block_found) {
            print "<IfModule mpm_worker_module>"
            print "    StartServers " start
            print "    MinSpareThreads " min
            print "    MaxSpareThreads " max
            print "    ThreadsPerChild " threads
            print "    MaxRequestWorkers " max_workers
            print "    MaxConnectionsPerChild " max_connections
            print "</IfModule>"
        }
    }
    ' /usr/local/apache2/conf/extra/httpd-mpm.conf > /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp && mv /usr/local/apache2/conf/extra/httpd-mpm.conf.tmp /usr/local/apache2/conf/extra/httpd-mpm.conf
fi

log_info "Apache MPM configuration completed"