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

if [ -f /config/prometheus.yml ]; then
    if [ -f /etc/prometheus/prometheus.yml ]; then
        rm /etc/prometheus/prometheus.yml
    fi
    ln -sf /config/prometheus.yml /etc/prometheus/prometheus.yml
fi

PROMETHEUS_ARG_LIST=(
    --config.file=${PROMETHEUS_CONFIG_FILE}
    --storage.tsdb.path=${PROMETHEUS_DATA_DIR}
    --web.listen-address=":${PROMETHEUS_PORT}"
)

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

exec prometheus "${PROMETHEUS_ARG_LIST[@]}"