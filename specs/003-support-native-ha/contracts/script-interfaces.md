# Contract: Script Interfaces

**Feature**: Support Native High Availability
**Spec**: `specs/003-support-native-ha/spec.md`

This document defines the interfaces for the shell scripts that will be modified or created to implement the native HA feature.

## 1. `entrypoint.d/scripts/utils/validation.sh`

### `validate_ha_configuration()`

- **Signature**: `validate_ha_configuration`
- **Description**: Validates all environment variables related to any High Availability mode. It will be extended to include `native` HA.
- **Inputs (Environment Variables)**:
  - `HA_MODE`
  - `REPLICATION_ROLE`
  - `PRIMARY_HOST`
  - `REPLICATION_PASSWORD`
  - `USE_PATRONI`
  - `USE_CITUS`
- **Outputs**:
  - **STDOUT**: None.
  - **STDERR**: Logs error messages if validation fails.
  - **Exit Code**: `0` on success, `1` on failure.
- **Contract**:
  - MUST be called before any configuration or initialization scripts are run.
  - MUST enforce the rules defined in the `Configuration Interface` contract.

## 2. `entrypoint.d/scripts/init/02-database.sh`

### `setup_database()`

- **Signature**: `setup_database`
- **Description**: Manages the PostgreSQL data directory (`$PGDATA`). It will be modified to handle replica initialization.
- **Inputs (Environment Variables)**:
  - `HA_MODE`
  - `REPLICATION_ROLE`
  - `PRIMARY_HOST`
  - `REPLICATION_USER`
  - `REPLICATION_PASSWORD`
  - `PGDATA`
- **Outputs**:
  - **STDOUT**: Logs progress messages (e.g., "Cloning primary database...").
  - **STDERR**: Logs error messages if `pg_basebackup` fails.
- **Contract**:
  - If `HA_MODE=native` and `REPLICATION_ROLE=replica`:
    - It MUST check if `$PGDATA` is empty.
    - If empty, it MUST execute `pg_basebackup` to populate `$PGDATA` from the `PRIMARY_HOST`.
    - It MUST use the `-R` flag with `pg_basebackup` to ensure the replica is correctly configured.
  - If the role is not a replica, it MUST defer to the existing `initdb` logic.

## 3. `entrypoint.d/scripts/init/03-config.sh`

### `configure_postgresql()`

- **Signature**: `configure_postgresql`
- **Description**: Modifies PostgreSQL configuration files (`postgresql.conf`, `pg_hba.conf`). It will be extended to configure the primary for replication.
- **Inputs (Environment Variables)**:
  - `HA_MODE`
  - `REPLICATION_ROLE`
  - `REPLICATION_USER`
- **Outputs**: None.
- **Contract**:
  - If `HA_MODE=native` and `REPLICATION_ROLE=primary`:
    - It MUST append the required replication settings to `postgresql.conf`.
    - It MUST add a `host` entry to `pg_hba.conf` to allow the `REPLICATION_USER` to connect from any host.

## 4. `entrypoint.d/scripts/init/04-replication.sh` (New Script)

### `create_replication_user()`

- **Signature**: `create_replication_user`
- **Description**: Creates the replication user on the primary server.
- **Inputs (Environment Variables)**:
  - `HA_MODE`
  - `REPLICATION_ROLE`
  - `REPLICATION_USER`
  - `REPLICATION_PASSWORD`
- **Outputs**:
  - **STDOUT**: Logs a message indicating the user is being created.
- **Contract**:
  - This script MUST only run if `HA_MODE=native` and `REPLICATION_ROLE=primary`.
  - It MUST be executed after `initdb` has run but before the database is made available for general connections.
  - It MUST create a PostgreSQL user with the `REPLICATION` privilege.
