#!/bin/bash

PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}

if [ -f /config/prometheus.yml ]; then
    if [ -f /etc/prometheus/prometheus.yml ]; then
        rm /etc/prometheus/prometheus.yml
    fi
    cp /config/prometheus.yml /etc/prometheus/prometheus.yml
fi

exec prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/opt/prometheus/data \
    --web.listen-address=":${PROMETHEUS_PORT}"