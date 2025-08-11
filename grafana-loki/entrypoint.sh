#!/bin/bash

GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki/loki"
    "serve"
    "--config.file=${GRAFANA_LOKI_CONFIG}"
)

exec "${GRAFANA_LOKI_ARG_LIST[@]}"