# Apache Airflow

This container provides Apache Airflow, a platform to programmatically author, schedule and monitor workflows.

## Features

- Apache Airflow 3.1.0
- SQLite database (for simple deployments)
- Web UI on port 8080
- Basic providers included (PostgreSQL, MySQL, HTTP, Docker)

## Usage

### Build

```bash
docker build -t supanadit/airflow:3.1.0 .
```

### Run

```bash
docker run -p 8080:8080 supanadit/airflow:3.1.0
```

Access the web UI at http://localhost:8080 with username `admin` and password `admin`.

### Volumes

- `/opt/airflow/dags` - DAGs folder
- `/opt/airflow/logs` - Logs folder
- `/opt/airflow/plugins` - Plugins folder

## Environment Variables

- `AIRFLOW_VERSION` - Airflow version to install (default: 3.1.0)
- `AIRFLOW_HOME` - Airflow home directory (default: /opt/airflow)