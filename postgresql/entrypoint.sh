#!/bin/bash

set -e

# Signal handling function
cleanup() {
    echo "Received shutdown signal, stopping PostgreSQL..."
    if [ -n "$POSTGRES_PID" ]; then
        kill -TERM "$POSTGRES_PID" 2>/dev/null || true
        wait "$POSTGRES_PID" 2>/dev/null || true
    fi
    # Clean up PID file if it exists
    if [ -f "/usr/local/pgsql/data/postmaster.pid" ]; then
        echo "Cleaning up PID file..."
        rm -f /usr/local/pgsql/data/postmaster.pid
    fi
    exit 0
}

# Set up signal traps
trap cleanup SIGTERM SIGINT SIGQUIT

# Ensure the data directory exists and has proper ownership
mkdir -p /usr/local/pgsql/data
chown -R postgres:postgres /usr/local/pgsql/data
chmod 700 /usr/local/pgsql/data

# Check if PostgreSQL data directory exists and is empty
if [ ! -d "/usr/local/pgsql/data" ] || [ -z "$(ls -A /usr/local/pgsql/data 2>/dev/null)" ]; then
    echo "Initializing PostgreSQL database cluster..."
    su - postgres -c "/usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data -k -A peer"
    echo "Database cluster initialized successfully."
else
    echo "PostgreSQL data directory already exists and is not empty. Skipping initialization."
fi

# Create /var/lib/pgbackrest if it doesn't exist
if [ ! -d "/var/lib/pgbackrest" ]; then
    mkdir -p /var/lib/pgbackrest
fi

chmod 750 /var/lib/pgbackrest
chown postgres:postgres /var/lib/pgbackrest

# Edit /etc/pgbackrest.conf to add default configuration if not already present
if ! grep -q "^\[default\]" /etc/pgbackrest.conf; then
    echo "Adding default configuration to /etc/pgbackrest.conf"
    {
        echo "[default]"
        echo "db-path=/usr/local/pgsql/data"
        echo ""
        echo "[global]"
        echo "repo-path=/var/lib/pgbackrest"
    } >> /etc/pgbackrest.conf
fi

# Add archive settings to postgresql.conf if not already present
if ! grep -q "^archive_mode = on" /usr/local/pgsql/data/postgresql.conf; then
    echo "Adding archive settings to postgresql.conf"
    {
        echo "archive_mode = on"
        echo "archive_command = 'pgbackrest --stanza=default archive-push %p'"
    } >> /etc/pgbackrest.conf
fi

if [ "$SLEEP_MODE" = "true" ]; then
    echo "Entering sleep mode for maintenance..."
    exec tail -f /dev/null
fi

# Clean up any stale PID file before starting
if [ -f "/usr/local/pgsql/data/postmaster.pid" ]; then
    echo "Removing stale PID file..."
    rm -f /usr/local/pgsql/data/postmaster.pid
fi

# Check if we need to run with Patroni or directly PostgreSQL
if [ "$USE_PATRONI" = "true" ]; then
    echo "Starting Patroni..."
    # Check Patroni /etc/patroni.yml exists
    if [ ! -f /etc/patroni.yml ]; then
        echo "Patroni configuration file /etc/patroni.yml not found!"
        exit 1
    fi
    su - postgres -c "patroni /etc/patroni.yml" &
    POSTGRES_PID=$!
else
    echo "Starting PostgreSQL..."
    # If arguments are provided, use them; otherwise use default PostgreSQL startup
    if [ $# -eq 0 ]; then
        su - postgres -c "/usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data" &
        POSTGRES_PID=$!
    else
        su - postgres -c "$*" &
        POSTGRES_PID=$!
    fi
fi

# Wait for the PostgreSQL process
wait "$POSTGRES_PID"