#!/bin/bash

# Default component is query
THANOS_COMPONENT=${THANOS_COMPONENT:-query}
THANOS_HTTP_ADDRESS=${THANOS_HTTP_ADDRESS:-0.0.0.0:10902}
THANOS_GRPC_ADDRESS=${THANOS_GRPC_ADDRESS:-0.0.0.0:10901}
THANOS_DATA_DIR=${THANOS_DATA_DIR:-/opt/thanos/data}

# Build base arguments
THANOS_ARG_LIST=(
    --http-address=${THANOS_HTTP_ADDRESS}
    --grpc-address=${THANOS_GRPC_ADDRESS}
)

case ${THANOS_COMPONENT} in
    query)
        THANOS_ARG_LIST+=(
            --query.replica-label=prometheus_replica
        )
        # Add store endpoints from environment
        if [ -n "${THANOS_QUERY_STORES}" ]; then
            IFS=',' read -ra STORES <<< "${THANOS_QUERY_STORES}"
            for store in "${STORES[@]}"; do
                THANOS_ARG_LIST+=(--store=${store})
            done
        fi
        ;;
    sidecar)
        THANOS_ARG_LIST+=(
            --prometheus.url=http://localhost:9090
            --tsdb.path=${THANOS_DATA_DIR}
        )
        ;;
    store)
        THANOS_ARG_LIST+=(
            --data-dir=${THANOS_DATA_DIR}
        )
        ;;
    *)
        echo "Unknown component: ${THANOS_COMPONENT}"
        exit 1
        ;;
esac

echo "Starting Thanos ${THANOS_COMPONENT} with arguments: ${THANOS_ARG_LIST[*]}"

exec thanos ${THANOS_COMPONENT} "${THANOS_ARG_LIST[@]}"