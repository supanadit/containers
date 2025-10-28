#!/bin/bash

set -e

# Get container IP address
CONTAINER_IP=$(hostname -i)

# Default MinIO configuration
export MINIO_DATA_DIR=${MINIO_DATA_DIR:-/var/lib/minio/data}
export MINIO_ADDRESS=${MINIO_ADDRESS:-:9000}
export MINIO_CONSOLE_ADDRESS=${MINIO_CONSOLE_ADDRESS:-:9001}
export MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
export MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}
export MINIO_BROWSER_REDIRECT_URL=${MINIO_BROWSER_REDIRECT_URL:-http://$CONTAINER_IP:9000}

# Create data directory
if [ ! -d "$MINIO_DATA_DIR" ]; then
    echo "Creating MinIO data directory at $MINIO_DATA_DIR"
    mkdir -p "$MINIO_DATA_DIR"
fi
chmod 755 "$MINIO_DATA_DIR"

# Function to start MinIO with default configuration
start_minio() {
    echo "Starting MinIO with configuration:"
    echo "  Data Dir: $MINIO_DATA_DIR"
    echo "  Address: $MINIO_ADDRESS"
    echo "  Console Address: $MINIO_CONSOLE_ADDRESS"
    echo "  Root User: $MINIO_ROOT_USER"
    echo ""
    
    # Store configuration values in local variables to avoid environment variable conflicts
    local data_dir="$MINIO_DATA_DIR"
    local address="$MINIO_ADDRESS"
    local console_address="$MINIO_CONSOLE_ADDRESS"
    
    # Unset environment variables to avoid conflicts with command-line flags
    unset MINIO_DATA_DIR
    unset MINIO_ADDRESS
    unset MINIO_CONSOLE_ADDRESS
    
    exec minio server "$data_dir" \
        --address="$address" \
        --console-address="$console_address"
}

# Check if first argument is minio or if no arguments provided
if [ "$#" -eq 0 ] || [ "$1" = "minio" ]; then
    start_minio
else
    # Execute any other command passed to the container
    exec "$@"
fi
