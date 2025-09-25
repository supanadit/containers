# Quickstart: Native PostgreSQL High Availability

**Feature**: Support Native High Availability
**Spec**: `specs/003-support-native-ha/spec.md`

This guide provides instructions for setting up a primary-replica cluster using the native streaming replication feature.

## 1. Prerequisites

- Docker and Docker Compose installed.
- A built `postgres-container` image.

## 2. Environment Variables

The following environment variables control the native HA feature:

| Variable | Description | Example |
|---|---|---|
| `HA_MODE` | Set to `native` to enable this feature. | `native` |
| `REPLICATION_ROLE` | Role of the instance: `primary` or `replica`. | `primary` |
| `PRIMARY_HOST` | **Replica only**: Hostname/IP of the primary server. | `primary-db` |
| `REPLICATION_USER` | Username for the replication connection. | `rep_user` |
| `REPLICATION_PASSWORD` | Password for the replication user. | `SuperSecret` |
| `POSTGRES_USER` | Standard PostgreSQL admin user. | `admin` |
| `POSTGRES_PASSWORD` | Standard PostgreSQL admin password. | `password` |

## 3. Docker Compose Example

Create a `docker-compose.yml` file to orchestrate the primary and replica containers.

```yaml
version: '3.8'

services:
  primary:
    image: postgres-container:latest
    container_name: postgres-primary
    hostname: postgres-primary
    environment:
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=password
      - HA_MODE=native
      - REPLICATION_ROLE=primary
      - REPLICATION_USER=rep_user
      - REPLICATION_PASSWORD=SuperSecret
    ports:
      - "5432:5432"
    volumes:
      - primary_data:/var/lib/postgresql/data
    networks:
      - postgres-net

  replica:
    image: postgres-container:latest
    container_name: postgres-replica
    hostname: postgres-replica
    depends_on:
      - primary
    environment:
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=password
      - HA_MODE=native
      - REPLICATION_ROLE=replica
      - PRIMARY_HOST=postgres-primary
      - REPLICATION_USER=rep_user
      - REPLICATION_PASSWORD=SuperSecret
    ports:
      - "5433:5432"
    volumes:
      - replica_data:/var/lib/postgresql/data
    networks:
      - postgres-net

volumes:
  primary_data:
  replica_data:

networks:
  postgres-net:
```

## 4. Running the Cluster

1.  **Start the services**:
    ```bash
    docker-compose up -d
    ```

2.  **Verify the Primary**:
    - Check the logs of the primary container. You should see it starting up as a normal PostgreSQL server and configured for replication.
    ```bash
    docker logs postgres-primary
    ```

3.  **Verify the Replica**:
    - Check the logs of the replica container. You will see it performing a `pg_basebackup` from the primary and then starting in recovery mode.
    ```bash
    docker logs postgres-replica
    ```
    - Look for lines like:
      ```
      LOG:  database system is ready to accept read-only connections
      ```

4.  **Test Replication**:
    - Connect to the primary and create a new table and some data.
    ```bash
    docker-compose exec primary psql -U admin -c "CREATE TABLE test (id INT); INSERT INTO test VALUES (1);"
    ```
    - Connect to the replica and verify that the data has been replicated.
    ```bash
    docker-compose exec replica psql -U admin -c "SELECT * FROM test;"
    # You should see the row with id = 1.
    ```

## 5. Switching HA Modes

To switch from native HA to another mode (e.g., standalone or Patroni), update the environment variables in your `docker-compose.yml` and restart the containers.

**Example: Switching to Standalone**

1.  Modify `docker-compose.yml` for the `primary` service:
    ```yaml
    # ...
    services:
      primary:
        # ...
        environment:
          - POSTGRES_USER=admin
          - POSTGRES_PASSWORD=password
          # - HA_MODE=native
          # - REPLICATION_ROLE=primary
          # - REPLICATION_USER=rep_user
          # - REPLICATION_PASSWORD=SuperSecret
    # ...
    ```

2.  Restart the container:
    ```bash
    docker-compose up -d --force-recreate primary
    ```
    The container will now start as a standalone PostgreSQL instance.
