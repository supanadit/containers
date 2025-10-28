#!/bin/bash

set -e

# Get container IP address
CONTAINER_IP=$(hostname -i)

# Default MinIO configuration
MINIO_DATA_DIR=${MINIO_DATA_DIR:-/var/lib/minio/data}
MINIO_ADDRESS=${MINIO_ADDRESS:-:9000}
MINIO_CONSOLE_ADDRESS=${MINIO_CONSOLE_ADDRESS:-:9001}
MINIO_ROOT_USER=${MINIO_ROOT_USER:-admin}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-admin}

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
    local root_user="$MINIO_ROOT_USER"
    local root_password="$MINIO_ROOT_PASSWORD"
    
    # Unset environment variables to avoid conflicts with command-line flags
    unset MINIO_DATA_DIR
    unset MINIO_ADDRESS
    unset MINIO_CONSOLE_ADDRESS
    unset MINIO_ROOT_USER
    unset MINIO_ROOT_PASSWORD
    
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
