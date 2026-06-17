# AGENTS.md

## Dockerfile Pattern

Multi-stage builds with three stages: `base → setup → runtime`.

```dockerfile
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

# ARG for every version pin (app, extensions, plugins)
ARG APP_VERSION=x.y.z
ARG EXTENSION_VERSION=x.y.z
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE ...

ENV PATH="/usr/local/app/bin:$PATH"

FROM base AS setup
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    chmod +x /opt/setup.sh && /opt/setup.sh && rm -rf /opt/setup/

FROM setup AS runtime
COPY entrypoint.d/ /opt/container/entrypoint.d/
COPY config/ /etc/somewhere/       # optional config templates
RUN chown -R appuser:appuser /opt/container/ && chmod -R 755 /opt/container/
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh || exit 1
EXPOSE 5432 6432 ...
ENTRYPOINT ["/entrypoint.sh"]
```

- `base` stage: FROM, ARGs, LABELs, ENV for paths
- `setup` stage: COPY setup scripts → RUN with BuildKit cache mounts → cleanup
- `runtime` stage: COPY entrypoint scripts (volatile) → chown → final touches
- `entrypoint.d/` goes into `/opt/container/entrypoint.d/`
- `.dockerignore` excludes everything except what's needed for build

## Setup Scripts (`setup/`)

`setup.sh` is the build-time orchestrator:

```bash
#!/bin/bash
set -e
SCRIPT_DIR="/opt/setup/scripts"
chmod +x ${SCRIPT_DIR}/*.sh

${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-<app>.sh
${SCRIPT_DIR}/03-install-<extension>.sh
...
${SCRIPT_DIR}/99-cleanup.sh
```

Each numbered script in `setup/scripts/` handles exactly one component:
- `01-install-dependencies.sh` — apt system packages and tooling
- `02-install-<app>.sh` — main application built/installed from source
- `03..NN-install-<plugin>.sh` — one script per extension/plugin, installed via the app's native mechanism (USE_PGXS, pip, go build, etc.)
- `99-cleanup.sh` — removes -dev packages, reinstalls runtime libs, cleans apt cache and /temp

## Adding a Plugin / Extension

1. Add `ARG` in Dockerfile for version pinning
2. Create `setup/scripts/NN-install-<plugin>.sh` (next available number, before 99)
3. Add execution line to `setup.sh` before `99-cleanup.sh`
4. If it needs runtime configuration: add handling in `03-config.sh` (e.g., `shared_preload_libraries`, config generation)
5. If it needs a runtime process: add startup in `startup.sh` (background with `&`, PID tracking)

## Entrypoint Structure

Every container uses the same modular lifecycle under `entrypoint.d/`:

```
entrypoint.d/
  entrypoint.sh           # Main orchestrator
  scripts/
    init/                 # Run once per container start, in numbered order
      00-misc-scripts.sh
      01-directories.sh
      02-database.sh      # (app-specific: initdb, restore, clone)
      03-config.sh        # Config generation, env overrides, HA setup
      04-backup.sh        # Backup tool config generation
      05-sshd.sh          # SSH setup for replication
    runtime/
      startup.sh          # exec'd from entrypoint, runs app as background process, handles signals
      shutdown.sh         # Graceful stop
      healthcheck.sh      # Docker HEALTHCHECK
      backup-scheduler.sh # Optional recurring task
    utils/
      logging.sh          # Structured logging (log_debug/info/warn/error)
      validation.sh       # Env/config validation functions
      security.sh         # Permission hardening, temp file creation
      helpers.sh          # is_truthy(), common helpers
      cluster.sh          # Cluster role detection, replication helpers
    misc/
      <callback>.sh       # App-specific callbacks (e.g., patroni callbacks)
```

### entrypoint.sh — Main Orchestrator

```bash
#!/bin/bash
set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/validation.sh
source /opt/container/entrypoint.d/scripts/utils/security.sh

# Default directories (env vars allow override)
export DEFAULT_VAR="${DEFAULT_VAR:-/opt/containers/<category>}"
export ACTUAL_VAR="$DEFAULT_VAR"

# Bool normalization via case
case "${FEATURE_ENABLE:-false}" in
    true|1|yes|on) FEATURE_ENABLE="true" ;;
    *) FEATURE_ENABLE="false" ;;
esac

main() {
    log_script_start "entrypoint.sh"
    validate_environment
    setup_signal_handlers
    run_initialization    # numbered init scripts in order
    start_runtime         # exec startup.sh
}
main "$@"
```

### Every script follows this template:

```bash
#!/bin/bash
# <script>.sh - One-line description

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/helpers.sh
# ... other needed utils

main() {
    log_script_start "<script>.sh"
    validate_environment
    # ... actual logic ...
    log_script_end "<script>.sh"
}
main "$@"
```

Key rules for every script:
- `set -euo pipefail` at top, never omitted
- `source` all needed utils explicitly
- `main "$@"` pattern — no top-level code
- `log_script_start` / `log_script_end` wrapping
- `validate_environment` before any side effects
- `is_truthy()` for boolean env vars, not direct string comparison

## Environment Variables

- Everything configurable by env var — the core differentiator from Bitnami
- Defaults declared in `entrypoint.sh` as `DEFAULT_*` then copied to actual vars
- Bool handling: normalize in entrypoint.sh, use `is_truthy()` in scripts
- Config-override pattern: `POSTGRESQL_CONFIG_*` env vars dynamically applied via `apply_postgres_setting()`
- Runtime features toggled via `_ENABLE` vars (PATRONI_ENABLE, PGBACKREST_ENABLE, PGBOUNCER_ENABLE, CITUS_ENABLE)

## Volume Paths

All persistent data uses `/opt/containers/<category>`:
- `/opt/containers/data` — Persistent application data
- `/opt/containers/config` — User-provided config files (flat or subdirectories)
- `/opt/containers/backup` — Backup repositories
- `/opt/containers/logs` — Persistent log output
- `/opt/containers/run` — PID files, Unix sockets

Application binary homes (e.g., `/usr/local/pgsql`, `/opt/kafka`) are NOT touched by this convention.

## Config Generation (03-config.sh pattern)

The config script follows this order:
1. **Backup originals** — save postgresql.conf.original, pg_hba.conf.original
2. **Copy user configs** — from `/opt/containers/config/` if provided
3. **Generate defaults** — secure defaults if no user config present
4. **Apply feature configs** — HA mode, replication, Patroni, pgBackRest archive
5. **Apply env overrides** — `POSTGRESQL_CONFIG_*` vars (run LAST to override everything)
6. **Generate subordinate configs** — Patroni YAML, PgBouncer INI

Config template files in `config/` use `${ENV_VAR}` placeholders replaced by `sed` at startup.

## Build Commands

```bash
# Standard build (uses layer caching)
cd docker/<name> && docker build -t supanadit/<name>:latest .

# NEVER use --no-cache — it destroys the multi-stage layer cache.
# Changing entrypoint scripts auto-rebuilds only the runtime stage.
```

## Related Repos

- `container-examples/` — Compose files: `<name>/compose.yaml` (basic), `compose.xxx.yaml` (variants)
- `container-docs/` — Docusaurus docs at `docs/<name>/`
