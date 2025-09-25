# Research: Native PostgreSQL High Availability

**Feature**: Support Native High Availability
**Spec**: `specs/003-support-native-ha/spec.md`

## 1. Technical Investigation

### Objective
Implement native PostgreSQL streaming replication to provide a simple, built-in High Availability (HA) solution. This approach serves as an alternative to Patroni for users who prefer a less complex setup.

### Key Concepts
- **Streaming Replication**: A standard PostgreSQL feature where a replica (standby) server connects to a primary (master) server and continuously streams WAL (Write-Ahead Logging) records. The replica can be a hot standby, allowing read-only queries.
- **Primary Server**: The main read/write server that accepts client connections and writes transactions to the WAL.
- **Replica Server**: A read-only server that replays WAL records from the primary. It can be promoted to a primary if the original primary fails.

### Implementation Steps

#### A. Primary Server Configuration (`REPLICATION_ROLE=primary`)

1.  **Modify `postgresql.conf`**:
    - `listen_addresses = '*'`: To accept connections from replicas.
    - `wal_level = replica`: Minimum level for streaming replication.
    - `max_wal_senders = 10`: Number of concurrent connections from replicas.
    - `wal_keep_size = 256MB`: (Postgres 13+) Amount of WAL files to keep for replicas. Replaces `wal_keep_segments`.
    - `hot_standby = on`: Allows read-only queries on replica servers.

2.  **Modify `pg_hba.conf`**:
    - Create a replication user and grant access.
    - Add a rule to allow the replication user to connect from the replica's IP range.
      ```hba
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      host    replication     replication_user 0.0.0.0/0               scram-sha-256
      ```

3.  **Create Replication User**:
    - A dedicated user with the `REPLICATION` role is required.
      ```sql
      CREATE USER replication_user WITH REPLICATION PASSWORD 'your_password';
      ```
    - This should be handled via an initialization script. The password can be passed via an environment variable (e.g., `REPLICATION_PASSWORD`).

#### B. Replica Server Configuration (`REPLICATION_ROLE=replica`)

1.  **Initial Setup**:
    - The replica must start with an identical copy of the primary's data directory. This is achieved using `pg_basebackup`.
    - The replica's data directory must be empty before running `pg_basebackup`.

2.  **Run `pg_basebackup`**:
    - The entrypoint script will need to detect if it's a replica and if the data directory is empty.
    - Command:
      ```bash
      pg_basebackup -h $PRIMARY_HOST -p 5432 -U replication_user -D $PGDATA -Fp -Xs -R
      ```
    - **Flags**:
        - `-h $PRIMARY_HOST`: The primary server's address (from the environment variable).
        - `-U replication_user`: The replication user.
        - `-D $PGDATA`: The data directory to write to.
        - `-Fp`: Plain format (not tar).
        - `-Xs`: Stream WAL content while the backup is being created.
        - `-R`: **Crucial flag**. Creates a `standby.signal` file and appends connection info to `postgresql.auto.conf`. This automatically configures the server to start as a replica.

3.  **`standby.signal` file**:
    - The presence of this empty file in the data directory tells PostgreSQL to start in recovery mode as a standby/replica.

4.  **`postgresql.auto.conf`**:
    - The `-R` flag in `pg_basebackup` will automatically add the `primary_conninfo` setting, for example:
      ```
      primary_conninfo = 'user=replication_user password=your_password host=primary_host port=5432'
      ```

#### C. Logic Flow in Entrypoint Scripts

1.  **Validation (`validation.sh`)**:
    - Add a new function to validate HA configuration.
    - If `HA_MODE=native`:
        - `REPLICATION_ROLE` must be `primary` or `replica`.
        - `USE_PATRONI` must not be `true`.
        - `USE_CITUS` must not be `true`.
    - If `REPLICATION_ROLE=replica`:
        - `PRIMARY_HOST` must be set.

2.  **Configuration (`03-config.sh` in `init`)**:
    - If `HA_MODE=native` and `REPLICATION_ROLE=primary`:
        - Append the necessary replication settings to `postgresql.conf`.
        - Modify `pg_hba.conf` to allow replication connections.
        - Create the replication user if it doesn't exist.

3.  **Database Initialization (`02-database.sh` in `init`)**:
    - If `HA_MODE=native` and `REPLICATION_ROLE=replica`:
        - Check if `$PGDATA` is empty.
        - If it is, run `pg_basebackup` to clone the primary.
        - The replica will then start normally, and because of `standby.signal`, it will enter recovery mode.

#### D. Switching HA Modes

- The logic is stateless and driven by environment variables.
- If a user switches from `HA_MODE=native` to `USE_PATRONI=true`, the native HA logic will no longer be triggered. Patroni's logic will take over. The user is responsible for ensuring the data directory is in a state Patroni can use (e.g., empty for a new cluster or from a previous Patroni backup).
- If a user removes all HA variables, the container starts as a standalone instance. The `standby.signal` file would need to be removed if it exists from a previous replica run. The entrypoint should handle this cleanup.

## 2. Unresolved Questions
- **Replica Promotion**: The current scope does not include automatic promotion of a replica to a primary. This would require a manual intervention (e.g., running `pg_promote()`) or a more complex external script. This should be documented as a limitation.
- **Replication Password**: How should the replication password be managed? For simplicity, a new environment variable `REPLICATION_PASSWORD` seems appropriate and consistent with existing variables like `POSTGRES_PASSWORD`.

## 3. Proof of Concept
A local PoC can be set up using Docker Compose:
```yaml
services:
  primary:
    image: postgres-container
    environment:
      - HA_MODE=native
      - REPLICATION_ROLE=primary
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=admin
      - REPLICATION_USER=replicator
      - REPLICATION_PASSWORD=secret
  replica:
    image: postgres-container
    environment:
      - HA_MODE=native
      - REPLICATION_ROLE=replica
      - PRIMARY_HOST=primary
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=admin
      - REPLICATION_USER=replicator
      - REPLICATION_PASSWORD=secret
```
This setup would validate the configuration and scripting logic.
