# AGENTS.md

Every container in this repository is built with **forge** and run under
**ezx**. There are no setup scripts and no shell entrypoints: the build is a
declarative `forge.toml` manifest, and the entrypoint is a single
`ezx bootstrap` JavaScript program. Shell is only allowed when it comes from an
upstream application (e.g. `pgpool-ii`'s own launchers); never write new shell.

## Dockerfile Pattern

Multi-stage builds with four stages: `base → toolchain → setup → runtime`.

```dockerfile
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base         # FROM, ARGs, LABELs, ENV for paths

FROM base AS toolchain               # download + checksum-verify forge
FROM toolchain AS setup              # COPY forge.toml; RUN forge build ...
FROM setup AS runtime                # download + checksum-verify ezx; COPY entrypoint.d/
```

Stage rules:

- **`toolchain`** downloads the pinned, checksum-verified `forge` release
  binary and nothing else, so bumping `FORGE_VERSION` invalidates a curl-sized
  layer instead of the entire build.
- **`setup`** copies `forge.toml`, inherits forge from `toolchain`, and runs
  `forge build`. The RUN refreshes the apt index first (forge shells out to
  apt-get), and removes forge afterwards.
- **`runtime`** downloads the pinned, checksum-verified `ezx` release binary
  (runtime-only, so it lives here, not in the build path), then copies the
  entrypoint scripts. This makes an `EZX_VERSION` bump a curl-sized layer and
  keeps entrypoint edits from re-downloading ezx.
- Never merge the forge download back into the `setup` RUN, and never download
  ezx before the `runtime` stage.

Version pins live in `ARG`s on the Dockerfile and are passed to forge as
`--var NAME=${NAME}`; the manifest declares matching values in `[vars]` as
fallbacks. `TARGETARCH` is mapped to the artifact architecture (e.g.
`--var ARCH=${TARGETARCH}`).

The `runtime` stage also pre-creates `/opt/containers/{data,config,logs,run,backup}`
and chowns them to the application user, because the parent `/opt` is root-owned
and `ezx` stays PID 1 (each supervised node drops privileges via
`process.user`/`process.group`). A container whose binary is copied forward from
the build stage (etcd, minio) creates its user in the runtime stage instead —
accounts from the build stage do not carry over.

## forge Manifests (`forge.toml`)

One `forge.toml` per container. A component is an ordered `ops` list and
dependencies are explicit `needs` edges. Typical shape:

1. **system-deps** — `packages` (`build`/`runtime`/`remove`), locale setup.
2. **identity** — the application `user`.
3. **application / jdk** — `binary_install`, `source_install`, or `raw` for
   pinned downloads (JDK tarballs are downloaded and checksum-verified via
   `raw`, exactly like the forge/ezx binaries, because `source_install.archive`
   has no checksum field).
4. **cleanup** — strip binaries, drop docs/man and non-English locales. Forge
   removes `build` packages automatically after all components finish, so the
   cleanup component only handles the extra trimming.

Notes:

- Source builds (`source_install { type = "git", strategy = "none" }`) run their
  build in `after` hooks, e.g. minio/etcd `make build` after a Go toolchain
  install. See `minio/forge.toml` and `etcd/forge.toml`.
- `no_cache = true` is set on manifests whose source build must not be cached
  (mariadb, kafka, wordpress).
- Package `remove` lists are filtered by forge to packages that are actually
  installed, so the same list is portable across base images.

## Entrypoint: `entrypoint.d/bootstrap/`

Every container ships the same small module set. `main.js` is the only
entrypoint script; it validates, sets up directories, writes config, registers
health routes, then calls a `start<App>()` that runs `chain.run({ nodes: [...] })`.

```
entrypoint.d/bootstrap/
  main.js         # orchestrator: umask -> dirs -> config -> validate -> run
  env.js          # single source of truth for every env var (env.bool/int)
  validation.js   # fail-fast checks before side effects
  directories.js  # create + chown the /opt/containers/* tree (best-effort)
  config.js       # env -> config file (config.build / yaml.build / FileProvision)
  runtime.js      # the supervised node(s) + argument matrix
  api.js          # routes + composite health on the shared health server
```

Some containers add extra modules: kafka has `kraft.js` + `util.js`; the
database images split `database.js`/`backup.js`; wordpress has `wpconfig.js`,
`phpini.js`, `apache.js`.

`main.js` contract:

```js
const { fs, log } = require("ezx");
const { SLEEP_MODE } = require("./env");
// ...
function main() {
    fs.umask(0o027);
    setupDirectories();
    provisionConfig();          // may be generateConfig() or seedDefaultConfig()
    if (!validateEnvironment()) throw new Error("Environment validation failed");
    if (SLEEP_MODE) { startSleep(); return; }
    registerOpsRoutes();       // MUST be before chain.run
    startApp();
}
main();
```

## ezx Rules

- **ezx stays PID 1 and supervises.** Nodes are never exec'd away; ezx forwards
  signals (`forwardSignals`), reaps zombies, rotates logs and probes readiness.
- **Register `api` routes before `chain.run`.** `chain.run` blocks the script, so
  routes registered after it never exist. When `EZX_HEALTH_ADDR` is unset the
  registration throws — wrap it in try/catch and log a warning so the app still
  starts.
- **An empty `value` is still an argument.** `argOperations` entries with
  `value: ""` emit `--flag=`; apps reject it. Guard every optional flag with an
  `if`.
- **Chowning must be best-effort.** `fs.ensureDir(dir, {owner})` and
  `fs.chownRecursive` recurse, so a `:ro` config mount would abort the whole
  container. Use guarded `chmodBestEffort`/`chownBestEffort` helpers.
- **Durations are nanoseconds.** `interval: 1e9` is 1s, `timeout: 5e9` is 5s.
- **Filter consumed secrets at spawn time.** `filterEnvPattern` strips variables
  from the child environment (e.g. etcd strips `^ETCD_` so its own env
  configuration cannot conflict with the explicit flags).
- **`env.get(name, default)` applies the default when the var is empty too.**
- **Scheduling** uses `scheduler.every(...)`/`scheduler.build(...)` as a node
  property for recurring jobs (mariadb, kafka, postgresql pgBackRest).

## CI

- `.github/workflows/build-and-publish-<name>.yml` builds and pushes on tags.
  The `build-args` in each workflow must match the Dockerfile `ARG`s.
- `.github/workflows/pr-test-<name>.yml` runs the compose suites in
  `docker/<name>/tests/` for exactly one container, filtered by `paths:` so a PR
  only builds and tests what it touched.

Every container has one. Each suite is a real compose scenario
(`tests/compose/<case>.yaml`) plus a `tests/scripts/run-<case>.sh`; the workflow
runs **every** `run-*.sh` it finds, so adding a case only means adding a script.
The image is built with the Dockerfile `ARG` defaults (no `build-args` to drift).
Each script asserts the contract: the app answers on its own protocol/API, the
composite health endpoint is healthy, the app runs as its dedicated non-root
user, and `ezx` is PID 1. Shell is fine here — these run on a CI runner, not
inside the image.

Builds cache in GHCR, not the Actions cache: `type=gha` is capped at 10 GB for
the whole repository and these images do not fit, so a cold build of one
evicted several others. Each workflow owns one tag,
`ghcr.io/supanadit/containers:buildcache-<name>` (release builds use
`buildcache-release-<name>[-<version>]`), written with `mode=max,ignore-error=true`
so a failed export never fails the build. That needs `packages: write` plus a
`docker/login-action` step in every workflow that builds.
