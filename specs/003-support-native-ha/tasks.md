# Tasks: Support Native High Availability

**Input**: Design documents from `/home/supanadit/Workspaces/Personal/Docker/containers/specs/003-support-native-ha/`

## Phase 3.1: Setup & Test Scaffolding
- [ ] **T001** [P] Create a new BATS test file for integration testing at `docker/postgresql/test/integration/test_native_ha.bats`. This file should contain placeholder tests for primary and replica functionality.
- [ ] **T002** [P] Create a new script file for the replication user at `docker/postgresql/entrypoint.d/scripts/init/04-replication.sh`.

## Phase 3.2: Core Implementation
- [ ] **T003** Implement the HA validation logic in `docker/postgresql/entrypoint.d/scripts/utils/validation.sh`.
    - **Details**: Create the `validate_ha_configuration` function as specified in the `script-interfaces.md` contract. It must check for the mutual exclusivity of `HA_MODE=native` with `USE_PATRONI` and `USE_CITUS`, and validate the presence of `REPLICATION_ROLE` and `PRIMARY_HOST` when required.
    - **Depends on**: None.
- [ ] **T004** Implement the replication user creation logic in `docker/postgresql/entrypoint.d/scripts/init/04-replication.sh`.
    - **Details**: Create the `create_replication_user` function. This script should only run when `HA_MODE=native` and `REPLICATION_ROLE=primary`. It must create the PostgreSQL user specified by `REPLICATION_USER` with the `REPLICATION` privilege.
    - **Depends on**: T002.
- [ ] **T005** Implement the primary server configuration logic in `docker/postgresql/entrypoint.d/scripts/init/03-config.sh`.
    - **Details**: Modify the `configure_postgresql` function to append replication settings to `postgresql.conf` and add the replication user to `pg_hba.conf` when the server is configured as a `primary`.
    - **Depends on**: None.
- [ ] **T006** Implement the replica initialization logic in `docker/postgresql/entrypoint.d/scripts/init/02-database.sh`.
    - **Details**: Modify the `setup_database` function to execute `pg_basebackup` when the container is started as a `replica` and the data directory is empty. It must use the `PRIMARY_HOST` to connect to the primary.
    - **Depends on**: None.

## Phase 3.3: Tests
- [ ] **T007** [P] Implement the contract test for the configuration interface in `docker/postgresql/test/integration/test_native_ha.bats`.
    - **Details**: Add BATS tests to verify that the container fails with the correct error messages when the environment variable configuration violates the contract (e.g., `HA_MODE=native` with `USE_PATRONI=true`).
    - **Depends on**: T001, T003.
- [ ] **T008** [P] Implement the integration test for the primary-replica setup in `docker/postgresql/test/integration/test_native_ha.bats`.
    - **Details**: Add a BATS test that starts a primary and a replica container, creates data on the primary, and verifies it is replicated to the replica, as described in the `quickstart.md`.
    - **Depends on**: T001, T004, T005, T006.

## Dependencies
- **T003**, **T005**, **T006** can be worked on in parallel.
- **T004** depends on **T002**.
- **T007** depends on **T001** and **T003**.
- **T008** depends on **T001** and all core implementation tasks (**T004**, **T005**, **T006**).

## Parallel Execution Example
The initial setup and core implementation tasks can be parallelized to a large degree.

**Group 1 (Core Logic):**
```bash
# These tasks modify different scripts and can be done concurrently.
# Agent executes:
/implement T003
/implement T005
/implement T006
```

**Group 2 (User Script & Tests):**
```bash
# After T002 is complete, T004 can start.
# In parallel, after T001 and T003 are done, T007 can start.
# Agent executes:
/implement T004
/implement T007
```

**Final Integration Test:**
```bash
# This task depends on all other implementation being complete.
# Agent executes:
/implement T008
```
