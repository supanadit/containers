#!/bin/bash

set -e

# Check if PostgreSQL data directory exists and is empty
if [ ! -d "/usr/local/pgsql/data" ] || [ -z "$(ls -A /usr/local/pgsql/data 2>/dev/null)" ]; then
    echo "Initializing PostgreSQL database cluster..."
    /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data
    echo "Database cluster initialized successfully."
else
    echo "PostgreSQL data directory already exists and is not empty. Skipping initialization."
fi

# Check if we need to run with Patroni or directly PostgreSQL
if [ "$USE_PATRONI" = "true" ]; then
    echo "Starting Patroni..."
    # Check Patroni /etc/patroni.yml exists
    if [ ! -f /etc/patroni.yml ]; then
        echo "Patroni configuration file /etc/patroni.yml not found!"
        exit 1
    fi
    exec patroni /etc/patroni.yml
else
    echo "Starting PostgreSQL..."
    # If arguments are provided, use them; otherwise use default PostgreSQL startup
    if [ $# -eq 0 ]; then
        exec /usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data -k
    else
        exec "$@"
    fi
fi