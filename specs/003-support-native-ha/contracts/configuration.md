# Contract: Configuration Interface

**Feature**: Support Native High Availability
**Spec**: `specs/003-support-native-ha/spec.md`

This document defines the contract for the configuration interface of the native HA feature.

## Environment Variables

The following environment variables are introduced to control the native HA functionality. Adherence to this contract is mandatory for predictable behavior.

| Variable | Type | Description | Constraints |
|---|---|---|---|
| `HA_MODE` | `string` | Activates the HA mode. Must be set to `native` for this feature. | Must be one of `native` or unset. Cannot be used with `USE_PATRONI` or `USE_CITUS`. |
| `REPLICATION_ROLE` | `string` | Specifies the role of the instance within the native HA cluster. | Required if `HA_MODE=native`. Must be `primary` or `replica`. |
| `PRIMARY_HOST` | `string` | The network address (hostname or IP) of the primary server. | Required if `REPLICATION_ROLE=replica`. |
| `REPLICATION_USER` | `string` | The username for the PostgreSQL user with `REPLICATION` privileges. | Defaults to `replicator`. |
| `REPLICATION_PASSWORD` | `string` | The password for the `REPLICATION_USER`. | Required if `HA_MODE=native`. Must not be empty. |

## Validation Logic

The container's entrypoint script MUST perform the following validation checks before proceeding with initialization:

1.  **Mutual Exclusivity**:
    - If `HA_MODE` is `native`, `USE_PATRONI` MUST NOT be `true`.
    - If `HA_MODE` is `native`, `USE_CITUS` MUST NOT be `true`.
    - *Failure Action*: Exit with a non-zero status code and log an error message specifying the conflict.

2.  **Role Definition**:
    - If `HA_MODE` is `native`, `REPLICATION_ROLE` MUST be either `primary` or `replica`.
    - *Failure Action*: Exit with a non-zero status code and log an error message indicating the missing or invalid role.

3.  **Replica Configuration**:
    - If `REPLICATION_ROLE` is `replica`, `PRIMARY_HOST` MUST be set and non-empty.
    - *Failure Action*: Exit with a non-zero status code and log an error message indicating the missing `PRIMARY_HOST`.

4.  **Authentication**:
    - If `HA_MODE` is `native`, `REPLICATION_PASSWORD` MUST be set and non-empty.
    - *Failure Action*: Exit with a non-zero status code and log an error message indicating the missing password.

## Behavior on Change

- Switching `HA_MODE` from `native` to another value or unsetting it will disable the native HA logic on the next container start.
- The entrypoint scripts are responsible for cleaning up any state files (e.g., `standby.signal`) from a previous run if the configuration changes.
