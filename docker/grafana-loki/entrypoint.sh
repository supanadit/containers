#!/bin/bash

if [ ! -f /config/loki.yaml ]; then
    cp /etc/loki/loki-sample.yaml /config/loki.yaml
fi

GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

if [ ! -f ${GRAFANA_LOKI_CONFIG} ]; then
    ln -sf /config/loki.yaml ${GRAFANA_LOKI_CONFIG}
fi

ENABLE_LISTEN_ALL_INTERFACE=${ENABLE_LISTEN_ALL_INTERFACE:-true}

if [ "${ENABLE_LISTEN_ALL_INTERFACE}" = "true" ]; then
    # It will check /config/loki.yaml on instance_addr: 127.0.0.1
    # Then will change to instance_addr: 0.0.0.0
    sed -i 's/instance_addr: 127.0.0.1/instance_addr: 0.0.0.0/g' /config/loki.yaml
fi

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki"
    "-config.file=${GRAFANA_LOKI_CONFIG}"
)

exec "${GRAFANA_LOKI_ARG_LIST[@]}"