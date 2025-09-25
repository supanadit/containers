# Data Model: Native HA

**Feature**: Support Native High Availability
**Spec**: `specs/003-support-native-ha/spec.md`

## 1. Script Architecture

The implementation will modify existing scripts to introduce the native HA logic, primarily controlled by environment variables.

### `entrypoint.d/scripts/utils/validation.sh`

- **`validate_ha_configuration()`** (New Function)
  - **Purpose**: Centralize all HA-related validation logic.
  - **Logic**:
    - Reads `HA_MODE`, `USE_PATRONI`, `USE_CITUS`, `REPLICATION_ROLE`, and `PRIMARY_HOST`.
    - **Checks**:
      1. If `HA_MODE == "native"`:
         - Fail if `USE_PATRONI == "true"`.
         - Fail if `USE_CITUS == "true"`.
         - Fail if `REPLICATION_ROLE` is not `primary` or `replica`.
         - If `REPLICATION_ROLE == "replica"`, fail if `PRIMARY_HOST` is not set.
    - **Integration**: This function will be called from the main `entrypoint.sh` orchestrator early in the startup sequence.

### `entrypoint.d/scripts/init/02-database.sh`

- **Modify `setup_database()`** (Existing Function)
  - **Purpose**: Handle the initial state of the data directory, now including replica setup.
  - **Logic**:
    - Add a condition: `if [[ "$HA_MODE" == "native" && "$REPLICATION_ROLE" == "replica" ]]`.
    - Inside the condition:
      - Check if the `$PGDATA` directory is empty.
      - If empty, execute `pg_basebackup` to clone the primary.
        - Use `PRIMARY_HOST`, `REPLICATION_USER`, and `REPLICATION_PASSWORD` for the connection.
        - Use the `-R` flag to create `standby.signal` and configure `primary_conninfo`.
      - If not empty, log a warning that it's assuming the data directory is already a valid replica and proceed.
    - The existing logic for `initdb` will be skipped for replicas, as `pg_basebackup` populates the data directory.

### `entrypoint.d/scripts/init/03-config.sh`

- **Modify `configure_postgresql()`** (Existing Function)
  - **Purpose**: Apply PostgreSQL configuration changes for the primary server.
  - **Logic**:
    - Add a condition: `if [[ "$HA_MODE" == "native" && "$REPLICATION_ROLE" == "primary" ]]`.
    - Inside the condition:
      - Append replication-specific settings to `postgresql.conf`:
        - `wal_level = replica`
        - `max_wal_senders = 10`
        - `wal_keep_size = 256MB`
        - `hot_standby = on`
      - Append a rule to `pg_hba.conf` to allow the replication user to connect.
        - `host replication $REPLICATION_USER 0.0.0.0/0 scram-sha-256`

### `entrypoint.d/scripts/init/01-users.sh` (or a new script `04-replication.sh`)

- **`create_replication_user()`** (New Function)
  - **Purpose**: Create the dedicated replication user on the primary.
  - **Logic**:
    - Add a condition: `if [[ "$HA_MODE" == "native" && "$REPLICATION_ROLE" == "primary" ]]`.
    - Inside the condition:
      - Execute a SQL command to create the user: `CREATE USER $REPLICATION_USER WITH REPLICATION PASSWORD '$REPLICATION_PASSWORD';`
  - **Integration**: This needs to run after `initdb` but before the main server process starts listening for connections. A new script `entrypoint.d/scripts/init/04-replication.sh` might be a cleaner place for this.

## 2. Configuration Interface

The feature is controlled entirely by environment variables.

| Variable | Role | Description | Default | Required |
|---|---|---|---|---|
| `HA_MODE` | Orchestration | Set to `native` to enable this feature. | (empty) | Yes (for this feature) |
| `REPLICATION_ROLE` | Orchestration | Defines the server's role. Either `primary` or `replica`. | (empty) | Yes (if `HA_MODE=native`) |
| `PRIMARY_HOST` | Configuration | The hostname or IP of the primary server. | (empty) | Yes (if `REPLICATION_ROLE=replica`) |
| `REPLICATION_USER` | Configuration | The username for the replication connection. | `replicator` | No |
| `REPLICATION_PASSWORD` | Secret | The password for the replication user. | (empty) | Yes (if `HA_MODE=native`) |

## 3. State Management

- **`standby.signal`**: The presence of this empty file in `$PGDATA` is the key state indicator for a replica. PostgreSQL itself manages this.
- **`postgresql.auto.conf`**: The `primary_conninfo` string written by `pg_basebackup` is another critical piece of state.
- **Stateless Logic**: The container's entrypoint scripts are designed to be stateless. They derive the desired state from environment variables on each startup and take action to converge the system to that state. For example, if a container that was a replica is restarted without the native HA variables, the scripts should ensure any leftover files like `standby.signal` are removed to prevent it from starting in recovery mode.
