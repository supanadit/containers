# Multi-stage build for Apache Airflow with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM python:3.12-bookworm AS base

ARG AIRFLOW_VERSION=3.1.0
ARG AIRFLOW_HOME=/opt/airflow

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="airflow" \
    org.opencontainers.image.description="Optimized Apache Airflow container" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

# Setup layer - copy stable files first for better caching
FROM base AS setup

# Set Airflow environment
ENV AIRFLOW_HOME=/opt/airflow
ENV PATH=/opt/airflow/bin:$PATH

# Copy setup scripts and configuration (stable files that change infrequently)
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer with BuildKit cache mounts
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    --mount=type=cache,target=/root/.cache/pip \
    chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

# Runtime layer - copy volatile files later
FROM setup AS runtime

# Set Airflow environment
ENV AIRFLOW_HOME=/opt/airflow
ENV PATH=/opt/airflow/bin:$PATH

# Copy configuration files
COPY config/ /opt/airflow/config/

# Copy main entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create airflow user
RUN groupadd -r airflow && useradd -r -g airflow airflow

# Create necessary directories
RUN mkdir -p /opt/airflow/logs /opt/airflow/dags /opt/airflow/plugins && \
    chown -R airflow:airflow /opt/airflow

# Switch to airflow user
USER airflow

# Expose Airflow webserver port
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]