#!/bin/bash

# Default component is query
THANOS_COMPONENT=${THANOS_COMPONENT:-query}
THANOS_HTTP_ADDRESS=${THANOS_HTTP_ADDRESS:-0.0.0.0:10902}
THANOS_GRPC_ADDRESS=${THANOS_GRPC_ADDRESS:-0.0.0.0:10901}

THANOS_RECEIVE_HASHRING_FILE=${THANOS_RECEIVE_HASHRING_FILE:-}
THANOS_RECEIVE_LOCAL_ENDPOINT=${THANOS_RECEIVE_LOCAL_ENDPOINT:-127.0.0.1:10901}
THANOS_REMOTE_WRITE_ADDRESS=${THANOS_REMOTE_WRITE_ADDRESS:-0.0.0.0:10903}

THANOS_DATA_DIR=${THANOS_DATA_DIR:-/opt/thanos/data}

THANOS_SIDECAR_PROMETHEUS_URL=${THANOS_SIDECAR_PROMETHEUS_URL:-http://localhost:9090}
THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED=${THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED:-false}

THANOS_REPLICA_LABEL=${THANOS_REPLICA_LABEL:-}

THANOS_RECEIVE_REPLICATION_FACTOR=${THANOS_RECEIVE_REPLICATION_FACTOR:-1}

# S3 Object Store Configuration
THANOS_S3_BUCKET=${THANOS_S3_BUCKET:-}
THANOS_S3_ENDPOINT=${THANOS_S3_ENDPOINT:-}
THANOS_S3_ACCESS_KEY=${THANOS_S3_ACCESS_KEY:-}
THANOS_S3_SECRET_KEY=${THANOS_S3_SECRET_KEY:-}
THANOS_S3_INSECURE=${THANOS_S3_INSECURE:-false}
THANOS_S3_SIGNATURE_V2=${THANOS_S3_SIGNATURE_V2:-false}

# S3 SSL/TLS Configuration
THANOS_S3_CA_FILE=${THANOS_S3_CA_FILE:-}
THANOS_S3_CERT_FILE=${THANOS_S3_CERT_FILE:-}
THANOS_S3_KEY_FILE=${THANOS_S3_KEY_FILE:-}
THANOS_S3_INSECURE_SKIP_VERIFY=${THANOS_S3_INSECURE_SKIP_VERIFY:-false}

# Function to generate S3 objstore config
generate_s3_config() {
    if [ -n "${THANOS_S3_BUCKET}" ] && [ -n "${THANOS_S3_ENDPOINT}" ] && [ -n "${THANOS_S3_ACCESS_KEY}" ] && [ -n "${THANOS_S3_SECRET_KEY}" ]; then
        cat <<EOF
type: S3
config:
  bucket: "${THANOS_S3_BUCKET}"
  endpoint: "${THANOS_S3_ENDPOINT}"
  access_key: "${THANOS_S3_ACCESS_KEY}"
  secret_key: "${THANOS_S3_SECRET_KEY}"
  insecure: ${THANOS_S3_INSECURE}
  signature_version2: ${THANOS_S3_SIGNATURE_V2}
EOF
        # Add SSL/TLS configuration if provided
        if [ -n "${THANOS_S3_CA_FILE}" ]; then
            echo "  ca_file: \"${THANOS_S3_CA_FILE}\""
        fi
        if [ -n "${THANOS_S3_CERT_FILE}" ]; then
            echo "  cert_file: \"${THANOS_S3_CERT_FILE}\""
        fi
        if [ -n "${THANOS_S3_KEY_FILE}" ]; then
            echo "  key_file: \"${THANOS_S3_KEY_FILE}\""
        fi
        if [ "${THANOS_S3_INSECURE_SKIP_VERIFY}" = "true" ]; then
            echo "  insecure_skip_verify: true"
        fi
    fi
}

# Function to add objstore config to arguments
add_objstore_config() {
    if [ -n "${THANOS_S3_BUCKET}" ] && [ -n "${THANOS_S3_ENDPOINT}" ] && [ -n "${THANOS_S3_ACCESS_KEY}" ] && [ -n "${THANOS_S3_SECRET_KEY}" ]; then
        local s3_config
        s3_config=$(generate_s3_config)
        local temp_file=/tmp/thanos_s3_config.yaml
        echo "${s3_config}" > "${temp_file}"
        THANOS_ARG_LIST+=(--objstore.config-file="${temp_file}")
    elif [ -n "${THANOS_OBJSTORE_CONFIG}" ]; then
        THANOS_ARG_LIST+=(--objstore.config=${THANOS_OBJSTORE_CONFIG})
    elif [ -n "${THANOS_OBJSTORE_CONFIG_FILE}" ]; then
        THANOS_ARG_LIST+=(--objstore.config-file=${THANOS_OBJSTORE_CONFIG_FILE})
    fi
}

# Build base arguments
THANOS_ARG_LIST=(
    --http-address=${THANOS_HTTP_ADDRESS}
)

# Add gRPC address for components that support it
case ${THANOS_COMPONENT} in
    query|sidecar|store|receive|rule)
        THANOS_ARG_LIST+=(--grpc-address=${THANOS_GRPC_ADDRESS})
        ;;
esac

case ${THANOS_COMPONENT} in
    query)
        if [ -n "${THANOS_REPLICA_LABEL}" ]; then
            THANOS_ARG_LIST+=(
                --query.replica-label=${THANOS_REPLICA_LABEL}
            )
        fi
        # Add store endpoints from environment
        if [ -n "${THANOS_QUERY_STORE_ADDRESSES}" ]; then
            IFS=',' read -ra STORES <<< "${THANOS_QUERY_STORE_ADDRESSES}"
            for store in "${STORES[@]}"; do
                THANOS_ARG_LIST+=(--endpoint=${store})
            done
        fi
        ;;
    sidecar)
        THANOS_ARG_LIST+=(
            --prometheus.url=${THANOS_SIDECAR_PROMETHEUS_URL}
            --tsdb.path=${THANOS_DATA_DIR}
        )
        if [ "${THANOS_SIDECAR_SHIPPER_UPLOAD_COMPACTED}" = "true" ]; then
            THANOS_ARG_LIST+=(
                --shipper.upload-compacted
            )
        fi
        # Add object store config if provided
        add_objstore_config
        ;;
    store)
        THANOS_ARG_LIST+=(
            --data-dir=${THANOS_DATA_DIR}
        )
        # Add object store config (required for store component)
        add_objstore_config
        ;;
    query-frontend)
        # Add downstream query URL if provided
        if [ -n "${THANOS_QUERY_FRONTEND_DOWNSTREAM_URL}" ]; then
            THANOS_ARG_LIST+=(--query-frontend.downstream-url=${THANOS_QUERY_FRONTEND_DOWNSTREAM_URL})
        fi
        ;;
    compact)
        THANOS_ARG_LIST+=(
            --data-dir=${THANOS_DATA_DIR}
            --wait
        )
        # Add object store config if provided
        add_objstore_config
        ;;
    receive)
        THANOS_ARG_LIST+=(
            --tsdb.path=${THANOS_DATA_DIR}
            --receive.replication-factor=${THANOS_RECEIVE_REPLICATION_FACTOR}
            --receive.local-endpoint=${THANOS_RECEIVE_LOCAL_ENDPOINT}
            --remote-write.address=${THANOS_REMOTE_WRITE_ADDRESS}
        )
        # If has hashring file, add it
        if [ -n "${THANOS_RECEIVE_HASHRING_FILE}" ]; then
            THANOS_ARG_LIST+=(--receive.hashring-file=${THANOS_RECEIVE_HASHRING_FILE})
        fi
        # Set replication factor
        # Add external labels from environment variables prefixed with THANOS_RECEIVE_LABELS_
        for var in $(env | grep '^THANOS_RECEIVE_LABELS_' | cut -d= -f1); do
            suffix=${var#THANOS_RECEIVE_LABELS_}
            key=$(echo "$suffix" | tr '[:upper:]' '[:lower:]')
            value=${!var}
            THANOS_ARG_LIST+=(--label="${key}=\"${value}\"")
        done
        # Add object store config if provided
        add_objstore_config
        ;;
    rule)
        THANOS_ARG_LIST+=(
            --data-dir=${THANOS_DATA_DIR}
        )
        # Add query endpoints if provided
        if [ -n "${THANOS_QUERY_ENDPOINTS}" ]; then
            IFS=',' read -ra ENDPOINTS <<< "${THANOS_QUERY_ENDPOINTS}"
            for endpoint in "${ENDPOINTS[@]}"; do
                THANOS_ARG_LIST+=(--query=${endpoint})
            done
        fi
        # Add rule files if provided
        if [ -n "${THANOS_RULE_FILES}" ]; then
            IFS=',' read -ra RULE_FILES <<< "${THANOS_RULE_FILES}"
            for rule_file in "${RULE_FILES[@]}"; do
                THANOS_ARG_LIST+=(--rule-file=${rule_file})
            done
        fi
        # Add alertmanager URLs if provided
        if [ -n "${THANOS_ALERTMANAGERS_URL}" ]; then
            IFS=',' read -ra AM_URLS <<< "${THANOS_ALERTMANAGERS_URL}"
            for am_url in "${AM_URLS[@]}"; do
                THANOS_ARG_LIST+=(--alertmanagers.url=${am_url})
            done
        fi
        # Add object store config if provided
        add_objstore_config
        ;;
    *)
        echo "Unknown component: ${THANOS_COMPONENT}"
        exit 1
        ;;
esac

echo "Starting Thanos ${THANOS_COMPONENT} with arguments: ${THANOS_ARG_LIST[*]}"

exec thanos ${THANOS_COMPONENT} "${THANOS_ARG_LIST[@]}"