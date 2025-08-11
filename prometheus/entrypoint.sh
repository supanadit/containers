#!/bin/bash

if [ -f /config/prometheus.yml ]; then
    if [ -f /etc/prometheus/prometheus.yml ]; then
        rm /etc/prometheus/prometheus.yml
    fi
    cp /config/prometheus.yml /etc/prometheus/prometheus.yml
fi

exec "$@"