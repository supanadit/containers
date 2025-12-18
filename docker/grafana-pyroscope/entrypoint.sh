#!/bin/bash
set -e

GRAFANA_PYROSCOPE_DATA=${GRAFANA_PYROSCOPE_DATA:-/var/lib/pyroscope/data}

GRAFANA_PYROSCOPE_ARG_LIST=(
    "/usr/share/grafana/pyroscope"
    "-pyroscopedb.data-path=${GRAFANA_PYROSCOPE_DATA}"
    "-target=all"
)

exec "${GRAFANA_PYROSCOPE_ARG_LIST[@]}"