## Why

Across all 21 containers in this project, volume mount paths (data, config, backup, logs, run) follow at least three different base-path conventions (`/opt/<app>/`, `/var/lib/<app>/`, `/usr/local/<app>/`) with no consistency. This makes it difficult for users to predict mount paths, complicates documentation, and prevents a unified mental model. Normalizing to a single `/opt/containers/<category>` prefix ensures every container behaves predictably, simplifies compose files, and aligns with the project's core value of providing a great developer experience without requiring deep Docker expertise.

## What Changes

- **BREAKING**: All default volume paths change from their current locations to `/opt/containers/<category>`:
  - Data: `/opt/containers/data`
  - Config: `/opt/containers/config`
  - Backup: `/opt/containers/backup`
  - Logs: `/opt/containers/logs`
  - Run (sockets/PID): `/opt/containers/run`
- **BREAKING**: All environment variables that control directory paths (e.g., `PGDATA`, `KAFKA_DATA_DIR`, `MARIADB_DATA_DIR`) default to the new normalized paths.
- **BREAKING**: Dockerfile `VOLUME` declarations (in prometheus, thanos) aligned to normalized paths.
- Config files support both flat files (`/opt/containers/config/postgresql.conf`) and subdirectories (`/opt/containers/config/ha/`).
- All 40+ example compose files updated to use new mount paths.
- New shared convention documented: application binary home stays at current location (e.g., `/opt/kafka`, `/usr/local/pgsql`); only persistent/customizable data uses `/opt/containers/`.
- Internal config templates (cassandra.yaml, zoo.cfg, server.properties, postgresql.conf, mimir.yaml, loki.yaml, tempo.yaml) updated to reference new paths.

## Capabilities

### New Capabilities

- `volume-normalization`: Standardizes volume mount paths across all 21 containers under `/opt/containers/<category>`, including data, config, backup, logs, and run directories.

### Modified Capabilities

<!-- No existing specs to modify -->

## Impact

- **All 21 container Dockerfiles**: Update `RUN mkdir`, `WORKDIR`, `VOLUME`, and directory creation commands.
- **All entrypoint scripts** (entrypoint.sh + entrypoint.d/): Update default env var values and directory references (~60+ script files).
- **All config templates**: Update embedded paths in yaml, properties, conf, cnf, cfg, ini files (~30+ files).
- **All 40+ example compose files**: Update volume mount source/target paths.
- **Documentation** (container-docs): Update all volume-related documentation to reflect new paths.
- **Users**: All existing deployments must update mount paths on upgrade. A migration guide will be provided.
