# Data Model: PostgreSQL Build Optimization

## Build Layer Model

### Setup Layer Entity
**Purpose**: Contains all build-time dependencies and installations that change infrequently.

**Attributes**:
- scripts: Array of setup script paths (01-install-dependencies.sh, 02-install-postgresql.sh, etc.)
- dependencies: List of system packages and versions
- build_artifacts: Temporary files created during build
- final_cleanup: Scripts to remove build artifacts

**Relationships**:
- Precedes: Entrypoint Layer
- Contains: Build-time configurations

### Entrypoint Layer Entity
**Purpose**: Contains runtime scripts and configurations that change frequently during development.

**Attributes**:
- entrypoint_script: Main entrypoint.sh path
- runtime_scripts: Array of entrypoint.d script paths
- configuration_files: Patroni config, PostgreSQL configs
- utility_scripts: Logging, validation, security utilities

**Relationships**:
- Depends on: Setup Layer (runtime dependencies)
- Contains: Runtime execution logic

### Cache Boundary Entity
**Purpose**: Defines the separation point between cached and non-cached layers.

**Attributes**:
- stable_files: Files copied early (setup scripts, dependencies)
- volatile_files: Files copied late (entrypoint scripts)
- cache_invalidation_rules: When to invalidate specific layers

**Relationships**:
- Separates: Setup Layer from Entrypoint Layer

## Validation Rules

### Layer Separation Rules
- Setup scripts must not depend on entrypoint scripts
- Entrypoint scripts must assume setup layer is complete
- Configuration files must be properly staged

### Cache Optimization Rules
- Files must be ordered by change frequency in COPY commands
- Volatile files must be copied after stable files
- Build context must exclude unnecessary files

## State Transitions

### Build States
1. Base Image → Setup Layer (install dependencies)
2. Setup Layer → Entrypoint Layer (copy runtime scripts)
3. Entrypoint Layer → Final Image (cleanup and finalize)

### Cache States
- Cache Hit: Reuse existing layers for unchanged files
- Cache Miss: Rebuild from changed layer onward
- Cache Invalidation: Force rebuild when dependencies change