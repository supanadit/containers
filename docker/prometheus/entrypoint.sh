#!/bin/bash

PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
PROMETHEUS_CONFIG_FILE=${PROMETHEUS_CONFIG_FILE:-/etc/prometheus/prometheus.yml}
PROMETHEUS_DATA_DIR=${PROMETHEUS_DATA_DIR:-/opt/prometheus/data}

# Features Flags
PROMETHEUS_ENABLE_NATIVE_HISTOGRAM=${PROMETHEUS_ENABLE_NATIVE_HISTOGRAM:-false}
PROMETHEUS_ENABLE_EXEMPLAR_STORAGE=${PROMETHEUS_ENABLE_EXEMPLAR_STORAGE:-false}
PROMETHEUS_ENABLE_MEMORY_SNAPSHOT_ON_SHUTDOWN=${PROMETHEUS_ENABLE_MEMORY_SNAPSHOT_ON_SHUTDOWN:-false}
PROMETHEUS_ENABLE_EXTRA_SCRAPE_METRICS=${PROMETHEUS_ENABLE_EXTRA_SCRAPE_METRICS:-false}
PROMETHEUS_ENABLE_PER_STEP_STATS=${PROMETHEUS_ENABLE_PER_STEP_STATS:-false}
PROMETHEUS_ENABLE_PROMQL_FUNCTIONS=${PROMETHEUS_ENABLE_PROMQL_FUNCTIONS:-false}
PROMETHEUS_ENABLE_CREATED_TIMESTAMPS_ZERO_INJECTION=${PROMETHEUS_ENABLE_CREATED_TIMESTAMPS_ZERO_INJECTION:-false}
PROMETHEUS_ENABLE_CONCURRENT_RULE_EVAL=${PROMETHEUS_ENABLE_CONCURRENT_RULE_EVAL:-false}
PROMETHEUS_ENABLE_OLD_UI=${PROMETHEUS_ENABLE_OLD_UI:-false}
PROMETHEUS_ENABLE_METADATA_WAL_RECORDS=${PROMETHEUS_ENABLE_METADATA_WAL_RECORDS:-false}
PROMETHEUS_ENABLE_DELAYED_COMPACTION=${PROMETHEUS_ENABLE_DELAYED_COMPACTION:-false}

PROMETHEUS_ENABLE_PROMQL_DELAYED_NAME_REMOVAL=${PROMETHEUS_ENABLE_PROMQL_DELAYED_NAME_REMOVAL:-false}
PROMETHEUS_ENABLE_AUTO_RELOAD_CONFIG=${PROMETHEUS_ENABLE_AUTO_RELOAD_CONFIG:-false}
PROMETHEUS_ENABLE_OLTP_DELTA_CONVERSION=${PROMETHEUS_ENABLE_OLTP_DELTA_CONVERSION:-false}
PROMETHEUS_ENABLE_PROMQL_DURATION_EXPR=${PROMETHEUS_ENABLE_PROMQL_DURATION_EXPR:-false}
PROMETHEUS_ENABLE_OLTP_NATIVE_DELTA=${PROMETHEUS_ENABLE_OLTP_NATIVE_DELTA:-false}
PROMETHEUS_ENABLE_TYPE_AND_UNIT_LABELS=${PROMETHEUS_ENABLE_TYPE_AND_UNIT_LABELS:-false}
PROMETHEUS_ENABLE_USE_UNCACHED_IO=${PROMETHEUS_ENABLE_USE_UNCACHED_IO:-false}
PROMETHEUS_ENABLE_WEB_LIFECYCLE=${PROMETHEUS_ENABLE_WEB_LIFECYCLE:-false}

PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER=${PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER:-false}
PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER=${PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER:-false}

# Storage TSDB Configuration
PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION=${PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION:-}
PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION=${PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION:-}
PROMETHEUS_STORAGE_TSDB_RETENTION_TIME=${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME:-}
PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=${PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE:-}

PROMETHEUS_ARG_LIST=(
    --config.file=${PROMETHEUS_CONFIG_FILE}
    --storage.tsdb.path=${PROMETHEUS_DATA_DIR}
    --web.listen-address=":${PROMETHEUS_PORT}"
)

# Add TSDB block durations if set
if [ -n "${PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION}" ]; then
    PROMETHEUS_ARG_LIST+=(
        --storage.tsdb.min-block-duration=${PROMETHEUS_STORAGE_TSDB_MIN_BLOCK_DURATION}
    )
fi

if [ -n "${PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION}" ]; then
    PROMETHEUS_ARG_LIST+=(
        --storage.tsdb.max-block-duration=${PROMETHEUS_STORAGE_TSDB_MAX_BLOCK_DURATION}
    )
fi

if [ -n "${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME}" ]; then
    PROMETHEUS_ARG_LIST+=(
        --storage.tsdb.retention.time=${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME}
    )
fi

if [ -n "${PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE}" ]; then
    PROMETHEUS_ARG_LIST+=(
        --storage.tsdb.retention.size=${PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE}
    )
fi

if [ "${PROMETHEUS_ENABLE_WEB_LIFECYCLE}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --web.enable-lifecycle
    )
fi

if [ "${PROMETHEUS_ENABLE_WEB_REMOTE_WRITE_RECEIVER}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --web.enable-remote-write-receiver
    )
fi

if [ "${PROMETHEUS_ENABLE_WEB_OTLP_RECEIVER}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --web.enable-otlp-receiver
    )
fi

if [ "${PROMETHEUS_ENABLE_NATIVE_HISTOGRAM}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=native-histograms
    )
fi

if [ "${PROMETHEUS_ENABLE_EXEMPLAR_STORAGE}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=exemplar-storage
    )
fi

if [ "${PROMETHEUS_ENABLE_MEMORY_SNAPSHOT_ON_SHUTDOWN}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=memory-snapshot-on-shutdown
    )
fi

if [ "${PROMETHEUS_ENABLE_EXTRA_SCRAPE_METRICS}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=extra-scrape-metrics
    )
fi

if [ "${PROMETHEUS_ENABLE_PER_STEP_STATS}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=promql-per-step-stats
    )
fi

if [ "${PROMETHEUS_ENABLE_PROMQL_FUNCTIONS}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=promql-experimental-functions
    )
fi

if [ "${PROMETHEUS_ENABLE_CREATED_TIMESTAMPS_ZERO_INJECTION}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=created-timestamp-zero-ingestion
    )
fi

if [ "${PROMETHEUS_ENABLE_CONCURRENT_RULE_EVAL}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=concurrent-rule-eval
    )
fi

if [ "${PROMETHEUS_ENABLE_OLD_UI}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=old-ui
    )
fi

if [ "${PROMETHEUS_ENABLE_METADATA_WAL_RECORDS}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=metadata-wal-records
    )
fi

if [ "${PROMETHEUS_ENABLE_DELAYED_COMPACTION}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=delayed-compaction
    )
fi

if [ "${PROMETHEUS_ENABLE_PROMQL_DELAYED_NAME_REMOVAL}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=promql-delayed-name-removal
    )
fi

if [ "${PROMETHEUS_ENABLE_AUTO_RELOAD_CONFIG}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=auto-reload-config
    )
fi

if [ "${PROMETHEUS_ENABLE_OLTP_DELTA_CONVERSION}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=oltp-delta-conversion
    )
fi

if [ "${PROMETHEUS_ENABLE_PROMQL_DURATION_EXPR}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=promql-duration-expr
    )
fi

if [ "${PROMETHEUS_ENABLE_OLTP_NATIVE_DELTA}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=otlp-native-delta-ingestion
    )
fi

if [ "${PROMETHEUS_ENABLE_TYPE_AND_UNIT_LABELS}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=type-and-unit-labels
    )
fi

if [ "${PROMETHEUS_ENABLE_USE_UNCACHED_IO}" = "true" ]; then
    PROMETHEUS_ARG_LIST+=(
        --enable-feature=use-uncached-io
    )
fi

# Check if a PROMETHEUS_CONFIG_FILE file exists, if not it will message and exit
if [ ! -f "${PROMETHEUS_CONFIG_FILE}" ]; then
    echo "Prometheus configuration file not found at ${PROMETHEUS_CONFIG_FILE}. Please create and mount it to the container."
    exit 1
fi

exec prometheus "${PROMETHEUS_ARG_LIST[@]}"