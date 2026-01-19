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

# Distributed MinIO configuration
export MINIO_DISTRIBUTED_MODE_ENABLED=${MINIO_DISTRIBUTED_MODE_ENABLED:-false}
export MINIO_DISTRIBUTED_NODES=${MINIO_DISTRIBUTED_NODES:-}  # e.g., "http://minio{1...4}/data{1...4}"

# Set MINIO_BROWSER_REDIRECT_URL only for standalone mode
# In distributed mode, this must be set explicitly or omitted to avoid mismatches
if [ "$MINIO_DISTRIBUTED_MODE_ENABLED" != "true" ]; then
    export MINIO_BROWSER_REDIRECT_URL=${MINIO_BROWSER_REDIRECT_URL:-http://$CONTAINER_IP:9000}
fi

# Create data directory (for standalone mode)
if [ "$MINIO_DISTRIBUTED_MODE_ENABLED" != "true" ]; then
    if [ ! -d "$MINIO_DATA_DIR" ]; then
        echo "Creating MinIO data directory at $MINIO_DATA_DIR"
        mkdir -p "$MINIO_DATA_DIR"
    fi
    chmod 755 "$MINIO_DATA_DIR"
fi

# Function to start MinIO in standalone mode
start_minio_standalone() {
    echo "Starting MinIO in STANDALONE mode with configuration:"
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
    unset MINIO_DISTRIBUTED_MODE_ENABLED
    unset MINIO_DISTRIBUTED_NODES
    
    exec minio server "$data_dir" \
        --address="$address" \
        --console-address="$console_address"
}

# Function to start MinIO in distributed mode
start_minio_distributed() {
    if [ -z "$MINIO_DISTRIBUTED_NODES" ]; then
        echo "ERROR: MINIO_DISTRIBUTED_NODES is required for distributed mode"
        echo "Example: MINIO_DISTRIBUTED_NODES='http://minio{1...4}/data{1...4}'"
        exit 1
    fi
    
    echo "Starting MinIO in DISTRIBUTED mode with configuration:"
    echo "  Nodes: $MINIO_DISTRIBUTED_NODES"
    echo "  Address: $MINIO_ADDRESS"
    echo "  Console Address: $MINIO_CONSOLE_ADDRESS"
    echo "  Root User: $MINIO_ROOT_USER"
    echo ""
    
    # Store configuration values in local variables to avoid environment variable conflicts
    local nodes="$MINIO_DISTRIBUTED_NODES"
    local address="$MINIO_ADDRESS"
    local console_address="$MINIO_CONSOLE_ADDRESS"
    
    # Unset environment variables to avoid conflicts with command-line flags
    unset MINIO_DATA_DIR
    unset MINIO_ADDRESS
    unset MINIO_CONSOLE_ADDRESS
    unset MINIO_DISTRIBUTED_MODE_ENABLED
    unset MINIO_DISTRIBUTED_NODES
    
    exec minio server $nodes \
        --address="$address" \
        --console-address="$console_address"
}

# Function to start MinIO based on mode
start_minio() {
    if [ "$MINIO_DISTRIBUTED_MODE_ENABLED" = "true" ]; then
        start_minio_distributed
    else
        start_minio_standalone
    fi
}

# Check if first argument is minio or if no arguments provided
if [ "$#" -eq 0 ] || [ "$1" = "minio" ]; then
    start_minio
else
    # Execute any other command passed to the container
    exec "$@"
fi
