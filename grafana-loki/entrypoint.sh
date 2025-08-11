#!/bin/bash

if [ ! -f /config/loki.yaml ]; then
    cp /etc/loki/loki-sample.yaml /config/loki.yaml
fi

GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

if [ ! -f ${GRAFANA_LOKI_CONFIG} ]; then
    ln -sf /config/loki.yaml ${GRAFANA_LOKI_CONFIG}
fi

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki"
    "-config.file=${GRAFANA_LOKI_CONFIG}"
)

exec "${GRAFANA_LOKI_ARG_LIST[@]}"