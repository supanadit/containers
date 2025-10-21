#!/bin/bash
set -e

echo "=== Installing Apache Airflow ==="

# Use AIRFLOW_VERSION from environment or default
AIRFLOW_VERSION=${AIRFLOW_VERSION:-3.1.0}

echo "Installing Apache Airflow ${AIRFLOW_VERSION}"

# Install Airflow with basic providers
pip install "apache-airflow==${AIRFLOW_VERSION}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-3.12.txt"

# Install additional useful providers
pip install "apache-airflow-providers-postgres" \
    "apache-airflow-providers-mysql" \
    "apache-airflow-providers-http" \
    "apache-airflow-providers-docker"

# Set AIRFLOW_HOME
export AIRFLOW_HOME=/opt/airflow
echo "AIRFLOW_HOME=${AIRFLOW_HOME}" >> /etc/environment

# Add to PATH
export PATH="${AIRFLOW_HOME}/bin:${PATH}"
echo "PATH=${AIRFLOW_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
airflow version

echo "=== Airflow installed successfully ==="