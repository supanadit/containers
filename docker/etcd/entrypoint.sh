#!/bin/bash

set -e

# Get container IP address
CONTAINER_IP=$(hostname -i)

# Default ETCD configuration
ETCD_NAME=${ETCD_NAME:-etcd-node}
ETCD_DATA_DIR=${ETCD_DATA_DIR:-/var/lib/etcd}
ETCD_LISTEN_PEER_URLS=${ETCD_LISTEN_PEER_URLS:-http://0.0.0.0:2380}
ETCD_LISTEN_CLIENT_URLS=${ETCD_LISTEN_CLIENT_URLS:-http://0.0.0.0:2379}
ETCD_ADVERTISE_CLIENT_URLS=${ETCD_ADVERTISE_CLIENT_URLS:-http://${CONTAINER_IP}:2379}
ETCD_INITIAL_ADVERTISE_PEER_URLS=${ETCD_INITIAL_ADVERTISE_PEER_URLS:-http://${CONTAINER_IP}:2380}
ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER:-${ETCD_NAME}=http://${CONTAINER_IP}:2380}
ETCD_INITIAL_CLUSTER_STATE=${ETCD_INITIAL_CLUSTER_STATE:-new}
ETCD_INITIAL_CLUSTER_TOKEN=${ETCD_INITIAL_CLUSTER_TOKEN:-etcd-cluster}

# Create data directory
if [ ! -d "$ETCD_DATA_DIR" ]; then
    echo "Creating ETCD data directory at $ETCD_DATA_DIR"
    mkdir -p "$ETCD_DATA_DIR"
fi
chmod 700 "$ETCD_DATA_DIR"

# Function to start ETCD with default configuration
start_etcd() {
    echo "Starting ETCD with configuration:"
    echo "  Name: $ETCD_NAME"
    echo "  Data Dir: $ETCD_DATA_DIR"
    echo "  Container IP: $CONTAINER_IP"
    echo "  Client URLs: $ETCD_LISTEN_CLIENT_URLS"
    echo "  Peer URLs: $ETCD_LISTEN_PEER_URLS"
    echo "  Advertise Client URLs: $ETCD_ADVERTISE_CLIENT_URLS"
    echo "  Advertise Peer URLs: $ETCD_INITIAL_ADVERTISE_PEER_URLS"
    echo "  Cluster: $ETCD_INITIAL_CLUSTER"
    echo ""
    
    exec etcd \
        --name="$ETCD_NAME" \
        --data-dir="$ETCD_DATA_DIR" \
        --listen-peer-urls="$ETCD_LISTEN_PEER_URLS" \
        --listen-client-urls="$ETCD_LISTEN_CLIENT_URLS" \
        --advertise-client-urls="$ETCD_ADVERTISE_CLIENT_URLS" \
        --initial-advertise-peer-urls="$ETCD_INITIAL_ADVERTISE_PEER_URLS" \
        --initial-cluster="$ETCD_INITIAL_CLUSTER" \
        --initial-cluster-state="$ETCD_INITIAL_CLUSTER_STATE" \
        --initial-cluster-token="$ETCD_INITIAL_CLUSTER_TOKEN" \
        --heartbeat-interval=1000 \
        --election-timeout=5000
}

# Check if first argument is etcd or if no arguments provided
if [ "$#" -eq 0 ] || [ "$1" = "etcd" ]; then
    start_etcd
else
    # Execute any other command passed to the container
    exec "$@"
fi