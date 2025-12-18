#!/bin/bash
set -e

# Default component is all (single-binary mode)
PYROSCOPE_COMPONENT=${PYROSCOPE_COMPONENT:-all}

# Server configuration
PYROSCOPE_HTTP_ADDRESS=${PYROSCOPE_HTTP_ADDRESS}
PYROSCOPE_GRPC_ADDRESS=${PYROSCOPE_GRPC_ADDRESS:-0.0.0.0:9095}

# Data paths
PYROSCOPE_DATA_PATH=${PYROSCOPE_DATA_PATH:-/var/lib/pyroscope/data}
PYROSCOPE_COMPACTOR_DATA_DIR=${PYROSCOPE_COMPACTOR_DATA_DIR:-/var/lib/pyroscope/compactor}

# Log configuration
PYROSCOPE_LOG_LEVEL=${PYROSCOPE_LOG_LEVEL:-info}
PYROSCOPE_LOG_FORMAT=${PYROSCOPE_LOG_FORMAT:-logfmt}

# Memberlist configuration
PYROSCOPE_MEMBERLIST_JOIN=${PYROSCOPE_MEMBERLIST_JOIN:-}
PYROSCOPE_MEMBERLIST_BIND_PORT=${PYROSCOPE_MEMBERLIST_BIND_PORT:-7946}
PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR=${PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR:-}
PYROSCOPE_MEMBERLIST_ADVERTISE_PORT=${PYROSCOPE_MEMBERLIST_ADVERTISE_PORT:-7946}

# Multitenancy
PYROSCOPE_AUTH_MULTITENANCY_ENABLED=${PYROSCOPE_AUTH_MULTITENANCY_ENABLED:-false}

# Storage backend configuration
PYROSCOPE_STORAGE_BACKEND=${PYROSCOPE_STORAGE_BACKEND:-}

# S3 Storage Configuration
PYROSCOPE_STORAGE_S3_BUCKET=${PYROSCOPE_STORAGE_S3_BUCKET:-}
PYROSCOPE_STORAGE_S3_ENDPOINT=${PYROSCOPE_STORAGE_S3_ENDPOINT:-}
PYROSCOPE_STORAGE_S3_REGION=${PYROSCOPE_STORAGE_S3_REGION:-}
PYROSCOPE_STORAGE_S3_ACCESS_KEY=${PYROSCOPE_STORAGE_S3_ACCESS_KEY:-}
PYROSCOPE_STORAGE_S3_SECRET_KEY=${PYROSCOPE_STORAGE_S3_SECRET_KEY:-}

# GCS Storage Configuration
PYROSCOPE_STORAGE_GCS_BUCKET=${PYROSCOPE_STORAGE_GCS_BUCKET:-}
PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT=${PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT:-}

# Azure Storage Configuration
PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME=${PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME:-}
PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY=${PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY:-}
PYROSCOPE_STORAGE_AZURE_CONTAINER=${PYROSCOPE_STORAGE_AZURE_CONTAINER:-}

# Filesystem Storage Configuration
PYROSCOPE_STORAGE_FILESYSTEM_DIR=${PYROSCOPE_STORAGE_FILESYSTEM_DIR:-/var/lib/pyroscope/shared}

# Storage prefix
PYROSCOPE_STORAGE_PREFIX=${PYROSCOPE_STORAGE_PREFIX:-}

# Distributor configuration
PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR=${PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR:-1}
PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB=${PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB:-4}
PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB=${PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB:-2}
PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED=${PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED:-false}

# Ingester configuration
PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT=${PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT:-5000}
PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT=${PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT:-0}
PYROSCOPE_INGESTER_AVAILABILITY_ZONE=${PYROSCOPE_INGESTER_AVAILABILITY_ZONE:-}

# Compactor configuration
PYROSCOPE_COMPACTOR_RETENTION_PERIOD=${PYROSCOPE_COMPACTOR_RETENTION_PERIOD:-}
PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED=${PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED:-true}

# Store Gateway configuration
PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE=${PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE:-0}
PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED=${PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED:-false}

# Querier configuration
PYROSCOPE_QUERIER_MAX_QUERY_LENGTH=${PYROSCOPE_QUERIER_MAX_QUERY_LENGTH:-1d}
PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK=${PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK:-7d}
PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM=${PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM:-0}
PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL=${PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL:-}

# Query Frontend configuration
PYROSCOPE_QUERY_FRONTEND_ADDRESS=${PYROSCOPE_QUERY_FRONTEND_ADDRESS:-}

# Query Scheduler configuration
PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS=${PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS:-100}

# Ring store configuration
PYROSCOPE_RING_STORE=${PYROSCOPE_RING_STORE:-memberlist}

# Build base arguments
PYROSCOPE_ARG_LIST=(
    "-log.level=${PYROSCOPE_LOG_LEVEL}"
    "-log.format=${PYROSCOPE_LOG_FORMAT}"
)

# Add server addresses
# HTTP for components that expose it
if [[ "${PYROSCOPE_HTTP_ADDRESS}" != "" ]]; then
    HTTP_PORT=${PYROSCOPE_HTTP_ADDRESS#:}
    PYROSCOPE_ARG_LIST+=("-server.http-listen-port=${HTTP_PORT}")
fi

# GRPC for all components
if [[ "${PYROSCOPE_GRPC_ADDRESS}" != "" ]]; then
    GRPC_PORT=${PYROSCOPE_GRPC_ADDRESS#:}
    PYROSCOPE_ARG_LIST+=("-server.grpc-listen-port=${GRPC_PORT}")
fi

# Add multitenancy if enabled
if [[ "${PYROSCOPE_AUTH_MULTITENANCY_ENABLED}" == "true" ]]; then
    PYROSCOPE_ARG_LIST+=("-auth.multitenancy-enabled")
fi

# Add memberlist configuration
if [[ -n "${PYROSCOPE_MEMBERLIST_JOIN}" ]]; then
    IFS=',' read -ra MEMBERS <<< "${PYROSCOPE_MEMBERLIST_JOIN}"
    for member in "${MEMBERS[@]}"; do
        PYROSCOPE_ARG_LIST+=("-memberlist.join=${member}")
    done
fi

if [[ -n "${PYROSCOPE_MEMBERLIST_BIND_PORT}" ]]; then
    PYROSCOPE_ARG_LIST+=("-memberlist.bind-port=${PYROSCOPE_MEMBERLIST_BIND_PORT}")
fi

if [[ -n "${PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR}" ]]; then
    PYROSCOPE_ARG_LIST+=("-memberlist.advertise-addr=${PYROSCOPE_MEMBERLIST_ADVERTISE_ADDR}")
fi

if [[ -n "${PYROSCOPE_MEMBERLIST_ADVERTISE_PORT}" ]]; then
    PYROSCOPE_ARG_LIST+=("-memberlist.advertise-port=${PYROSCOPE_MEMBERLIST_ADVERTISE_PORT}")
fi

# Add storage backend configuration
if [[ -n "${PYROSCOPE_STORAGE_BACKEND}" ]]; then
    PYROSCOPE_ARG_LIST+=("-storage.backend=${PYROSCOPE_STORAGE_BACKEND}")
    
    # S3 Configuration
    if [[ "${PYROSCOPE_STORAGE_BACKEND}" == "s3" ]]; then
        [[ -n "${PYROSCOPE_STORAGE_S3_BUCKET}" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.bucket-name=${PYROSCOPE_STORAGE_S3_BUCKET}")
        [[ -n "${PYROSCOPE_STORAGE_S3_ENDPOINT}" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.endpoint=${PYROSCOPE_STORAGE_S3_ENDPOINT}")
        [[ -n "${PYROSCOPE_STORAGE_S3_REGION}" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.region=${PYROSCOPE_STORAGE_S3_REGION}")
        [[ -n "${PYROSCOPE_STORAGE_S3_ACCESS_KEY}" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.access-key-id=${PYROSCOPE_STORAGE_S3_ACCESS_KEY}")
        [[ -n "${PYROSCOPE_STORAGE_S3_SECRET_KEY}" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.secret-access-key=${PYROSCOPE_STORAGE_S3_SECRET_KEY}")
        [[ "${PYROSCOPE_STORAGE_S3_INSECURE}" == "true" ]] && PYROSCOPE_ARG_LIST+=("-storage.s3.insecure")
    fi
    
    # GCS Configuration
    if [[ "${PYROSCOPE_STORAGE_BACKEND}" == "gcs" ]]; then
        [[ -n "${PYROSCOPE_STORAGE_GCS_BUCKET}" ]] && PYROSCOPE_ARG_LIST+=("-storage.gcs.bucket-name=${PYROSCOPE_STORAGE_GCS_BUCKET}")
        [[ -n "${PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT}" ]] && PYROSCOPE_ARG_LIST+=("-storage.gcs.service-account=${PYROSCOPE_STORAGE_GCS_SERVICE_ACCOUNT}")
    fi
    
    # Azure Configuration
    if [[ "${PYROSCOPE_STORAGE_BACKEND}" == "azure" ]]; then
        [[ -n "${PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME}" ]] && PYROSCOPE_ARG_LIST+=("-storage.azure.account-name=${PYROSCOPE_STORAGE_AZURE_ACCOUNT_NAME}")
        [[ -n "${PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY}" ]] && PYROSCOPE_ARG_LIST+=("-storage.azure.account-key=${PYROSCOPE_STORAGE_AZURE_ACCOUNT_KEY}")
        [[ -n "${PYROSCOPE_STORAGE_AZURE_CONTAINER}" ]] && PYROSCOPE_ARG_LIST+=("-storage.azure.container-name=${PYROSCOPE_STORAGE_AZURE_CONTAINER}")
    fi
    
    # Filesystem Configuration
    if [[ "${PYROSCOPE_STORAGE_BACKEND}" == "filesystem" ]]; then
        PYROSCOPE_ARG_LIST+=("-storage.filesystem.dir=${PYROSCOPE_STORAGE_FILESYSTEM_DIR}")
    fi
fi

# Add storage prefix if set
if [[ -n "${PYROSCOPE_STORAGE_PREFIX}" ]]; then
    PYROSCOPE_ARG_LIST+=("-storage.prefix=${PYROSCOPE_STORAGE_PREFIX}")
fi

# Component-specific configurations
case ${PYROSCOPE_COMPONENT} in
    all)
        PYROSCOPE_ARG_LIST+=(
            "-target=all"
            "-pyroscopedb.data-path=${PYROSCOPE_DATA_PATH}"
        )
        ;;
    distributor)
        PYROSCOPE_ARG_LIST+=(
            "-target=distributor"
            "-distributor.replication-factor=${PYROSCOPE_DISTRIBUTOR_REPLICATION_FACTOR}"
            "-distributor.ingestion-rate-limit-mb=${PYROSCOPE_DISTRIBUTOR_INGESTION_RATE_LIMIT_MB}"
            "-distributor.ingestion-burst-size-mb=${PYROSCOPE_DISTRIBUTOR_INGESTION_BURST_SIZE_MB}"
        )
        if [[ "${PYROSCOPE_DISTRIBUTOR_ZONE_AWARENESS_ENABLED}" == "true" ]]; then
            PYROSCOPE_ARG_LIST+=("-distributor.zone-awareness-enabled")
        fi
        ;;
    ingester)
        PYROSCOPE_ARG_LIST+=(
            "-target=ingester"
            "-pyroscopedb.data-path=${PYROSCOPE_DATA_PATH}"
        )
        if [[ ${PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT} -gt 0 ]]; then
            PYROSCOPE_ARG_LIST+=("-ingester.max-global-series-per-tenant=${PYROSCOPE_INGESTER_MAX_GLOBAL_SERIES_PER_TENANT}")
        fi
        if [[ ${PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT} -gt 0 ]]; then
            PYROSCOPE_ARG_LIST+=("-ingester.max-local-series-per-tenant=${PYROSCOPE_INGESTER_MAX_LOCAL_SERIES_PER_TENANT}")
        fi
        if [[ -n "${PYROSCOPE_INGESTER_AVAILABILITY_ZONE}" ]]; then
            PYROSCOPE_ARG_LIST+=("-ingester.availability-zone=${PYROSCOPE_INGESTER_AVAILABILITY_ZONE}")
        fi
        ;;
    compactor)
        PYROSCOPE_ARG_LIST+=(
            "-target=compactor"
            "-compactor.data-dir=${PYROSCOPE_COMPACTOR_DATA_DIR}"
        )
        if [[ -n "${PYROSCOPE_COMPACTOR_RETENTION_PERIOD}" ]]; then
            PYROSCOPE_ARG_LIST+=("-compactor.blocks-retention-period=${PYROSCOPE_COMPACTOR_RETENTION_PERIOD}")
        fi
        if [[ "${PYROSCOPE_COMPACTOR_DOWNSAMPLER_ENABLED}" == "true" ]]; then
            PYROSCOPE_ARG_LIST+=("-compactor.compactor-downsampler-enabled")
        fi
        ;;
    querier)
        PYROSCOPE_ARG_LIST+=(
            "-target=querier"
        )
        if [[ -n "${PYROSCOPE_QUERIER_MAX_QUERY_LENGTH}" ]]; then
            PYROSCOPE_ARG_LIST+=("-querier.max-query-length=${PYROSCOPE_QUERIER_MAX_QUERY_LENGTH}")
        fi
        if [[ -n "${PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK}" ]]; then
            PYROSCOPE_ARG_LIST+=("-querier.max-query-lookback=${PYROSCOPE_QUERIER_MAX_QUERY_LOOKBACK}")
        fi
        if [[ ${PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM} -gt 0 ]]; then
            PYROSCOPE_ARG_LIST+=("-querier.max-query-parallelism=${PYROSCOPE_QUERIER_MAX_QUERY_PARALLELISM}")
        fi
        if [[ -n "${PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL}" ]]; then
            PYROSCOPE_ARG_LIST+=("-querier.split-queries-by-interval=${PYROSCOPE_QUERIER_SPLIT_QUERIES_BY_INTERVAL}")
        fi
        ;;
    store-gateway)
        PYROSCOPE_ARG_LIST+=(
            "-target=store-gateway"
        )
        if [[ ${PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE} -gt 0 ]]; then
            PYROSCOPE_ARG_LIST+=("-store-gateway.tenant-shard-size=${PYROSCOPE_STORE_GATEWAY_TENANT_SHARD_SIZE}")
        fi
        if [[ "${PYROSCOPE_STORE_GATEWAY_ZONE_AWARENESS_ENABLED}" == "true" ]]; then
            PYROSCOPE_ARG_LIST+=("-store-gateway.sharding-ring.zone-awareness-enabled")
        fi
        ;;
    query-frontend)
        PYROSCOPE_ARG_LIST+=(
            "-target=query-frontend"
        )
        if [[ -n "${PYROSCOPE_QUERY_FRONTEND_ADDRESS}" ]]; then
            PYROSCOPE_ARG_LIST+=("-query-frontend.address=${PYROSCOPE_QUERY_FRONTEND_ADDRESS}")
        fi
        ;;
    query-scheduler)
        PYROSCOPE_ARG_LIST+=(
            "-target=query-scheduler"
        )
        if [[ ${PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS} -gt 0 ]]; then
            PYROSCOPE_ARG_LIST+=("-query-scheduler.max-outstanding-requests-per-tenant=${PYROSCOPE_QUERY_SCHEDULER_MAX_OUTSTANDING_REQUESTS}")
        fi
        ;;
    *)
        echo "Unknown component: ${PYROSCOPE_COMPONENT}"
        echo "Available components: all, distributor, ingester, compactor, querier, store-gateway, query-frontend, query-scheduler"
        exit 1
        ;;
esac

# Validate storage configuration for microservices mode
# In microservices mode, all components except 'all' need storage backend configured
if [[ "${PYROSCOPE_COMPONENT}" != "all" ]] && [[ -z "${PYROSCOPE_STORAGE_BACKEND}" ]]; then
    echo "ERROR: Storage backend must be configured when running in microservices mode."
    echo "Please set PYROSCOPE_STORAGE_BACKEND environment variable (s3, gcs, azure, or filesystem)."
    exit 1
fi

echo "Starting Pyroscope ${PYROSCOPE_COMPONENT} with arguments: ${PYROSCOPE_ARG_LIST[*]}"

exec /usr/share/grafana/pyroscope "${PYROSCOPE_ARG_LIST[@]}"