#!/bin/bash
set -e

# Set environment variables
export AIRFLOW_HOME=/opt/airflow
export PATH=/opt/airflow/bin:$PATH

# Initialize Airflow database if not already initialized
if [ ! -f /opt/airflow/airflow.db ]; then
    echo "Initializing Airflow database..."
    airflow db migrate
fi

# Start Airflow API server (which serves the web UI)
echo "Starting Airflow API server..."
exec airflow api-server --port 8080 --host 0.0.0.0