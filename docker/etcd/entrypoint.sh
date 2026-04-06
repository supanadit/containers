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

ETCD_CERT_FILE=${ETCD_CERT_FILE:-}
ETCD_KEY_FILE=${ETCD_KEY_FILE:-}
ETCD_CLIENT_CERT_AUTH=${ETCD_CLIENT_CERT_AUTH:-false}
ETCD_TRUSTED_CA_FILE=${ETCD_TRUSTED_CA_FILE:-}
ETCD_PEER_CERT_FILE=${ETCD_PEER_CERT_FILE:-}
ETCD_PEER_KEY_FILE=${ETCD_PEER_KEY_FILE:-}
ETCD_PEER_CLIENT_CERT_AUTH=${ETCD_PEER_CLIENT_CERT_AUTH:-false}
ETCD_PEER_TRUSTED_CA_FILE=${ETCD_PEER_TRUSTED_CA_FILE:-}

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
    
    # Store configuration values in local variables to avoid environment variable conflicts
    local name="$ETCD_NAME"
    local data_dir="$ETCD_DATA_DIR"
    local listen_peer_urls="$ETCD_LISTEN_PEER_URLS"
    local listen_client_urls="$ETCD_LISTEN_CLIENT_URLS"
    local advertise_client_urls="$ETCD_ADVERTISE_CLIENT_URLS"
    local initial_advertise_peer_urls="$ETCD_INITIAL_ADVERTISE_PEER_URLS"
    local initial_cluster="$ETCD_INITIAL_CLUSTER"
    local initial_cluster_state="$ETCD_INITIAL_CLUSTER_STATE"
    local initial_cluster_token="$ETCD_INITIAL_CLUSTER_TOKEN"
    
    unset ETCD_NAME
    unset ETCD_DATA_DIR
    unset ETCD_LISTEN_PEER_URLS
    unset ETCD_LISTEN_CLIENT_URLS
    unset ETCD_ADVERTISE_CLIENT_URLS
    unset ETCD_INITIAL_ADVERTISE_PEER_URLS
    unset ETCD_INITIAL_CLUSTER
    unset ETCD_INITIAL_CLUSTER_STATE
    unset ETCD_INITIAL_CLUSTER_TOKEN
    
    local etcd_args=(
        --name="$name"
        --data-dir="$data_dir"
        --listen-peer-urls="$listen_peer_urls"
        --listen-client-urls="$listen_client_urls"
        --advertise-client-urls="$advertise_client_urls"
        --initial-advertise-peer-urls="$initial_advertise_peer_urls"
        --initial-cluster="$initial_cluster"
        --initial-cluster-state="$initial_cluster_state"
        --initial-cluster-token="$initial_cluster_token"
        --heartbeat-interval=1000
        --election-timeout=5000
        --snapshot-count=5000
        --auto-compaction-retention=1
        --max-request-bytes=10485760
    )
    
    if [ -n "$ETCD_CERT_FILE" ]; then
        etcd_args+=(--cert-file="$ETCD_CERT_FILE")
    fi
    if [ -n "$ETCD_KEY_FILE" ]; then
        etcd_args+=(--key-file="$ETCD_KEY_FILE")
    fi
    if [ "$ETCD_CLIENT_CERT_AUTH" = "true" ]; then
        etcd_args+=(--client-cert-auth=true)
    fi
    if [ -n "$ETCD_TRUSTED_CA_FILE" ]; then
        etcd_args+=(--trusted-ca-file="$ETCD_TRUSTED_CA_FILE")
    fi
    if [ -n "$ETCD_PEER_CERT_FILE" ]; then
        etcd_args+=(--peer-cert-file="$ETCD_PEER_CERT_FILE")
    fi
    if [ -n "$ETCD_PEER_KEY_FILE" ]; then
        etcd_args+=(--peer-key-file="$ETCD_PEER_KEY_FILE")
    fi
    if [ "$ETCD_PEER_CLIENT_CERT_AUTH" = "true" ]; then
        etcd_args+=(--peer-client-cert-auth=true)
    fi
    if [ -n "$ETCD_PEER_TRUSTED_CA_FILE" ]; then
        etcd_args+=(--peer-trusted-ca-file="$ETCD_PEER_TRUSTED_CA_FILE")
    fi
    
    exec etcd "${etcd_args[@]}"
}

# Check if first argument is etcd or if no arguments provided
if [ "$#" -eq 0 ] || [ "$1" = "etcd" ]; then
    start_etcd
else
    # Execute any other command passed to the container
    exec "$@"
fi