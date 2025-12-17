#!/bin/bash
set -e

GRAFANA_PYROSCOPE_ARG_LIST=(
    "/usr/share/grafana/pyroscope"
    "-api.base-url"
    "/pyroscope"
)

exec "${GRAFANA_PYROSCOPE_ARG_LIST[@]}"