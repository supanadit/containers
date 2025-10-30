# Containers Project - AI Agent Instructions

## Architecture Overview
This repository contains optimized Docker containers for big data and infrastructure services. Each container follows a consistent multi-stage build pattern with standardized structure:

- **Base Stage**: Debian base image
- **Setup Stage**: System dependencies and application installation via numbered scripts, always build from source code when possible
- **Runtime Stage**: Configuration files and entrypoint

Key directories: `docker/{service}/` with consistent structure across all containers.

## Build Patterns
- **Multi-stage Dockerfiles** with BuildKit cache mounts (`--mount=type=cache,target=/var/cache/apt`)
- **Setup Scripts**: Numbered scripts in `setup/scripts/` (01-install-dependencies.sh, 02-install-*.sh, 99-cleanup.sh)
- **Standardized Environment**: `{SERVICE}_HOME=/opt/{service}`, `PATH` includes service binaries
- **Non-root Users**: Dedicated service user with proper directory ownership
- **Base Images**: Debian Linux variants for consistency

## Development Workflow
- **Feature Branches**: Use `.specify/scripts/bash/create-new-feature.sh` for standardized branch naming
- **Constitution Compliance**: All changes must follow `.specify/memory/constitution.md` principles
- **CI/CD**: GitHub Actions triggers on releases, builds matrix of versions, publishes to GHCR
- **Release Tagging**: Format `{container}[-{variant}]-{revision}` (e.g., `airflow-3.1.0`, `wordpress-apache-6.8.3`)

## Key Conventions
- **Configuration**: Environment variables preferred over files; configs in `config/` directory
- **Volumes**: Standardized mount points (`/opt/{service}/data`, `/opt/{service}/logs`)
- **Documentation**: Each container has README.md with build/run examples and environment variables
- **Dependencies**: System packages via apt, application dependencies via dedicated install scripts

## Integration Points
- **GitHub Container Registry**: Images published as `ghcr.io/{owner}/containers/{service}:{version}`
- **Cross-container**: Services designed to work together (PostgreSQL + Airflow, Cassandra + Kafka)
- **Environment Compatibility**: Works in local dev, CI/CD, and cloud deployments

## Examples
- **Adding New Container**: Copy existing structure from `docker/airflow/`, update versions in workflow matrix
- **Modifying Setup**: Edit numbered scripts in `setup/scripts/`, maintain execution order
- **Configuration**: Add env vars to Dockerfile and document in README.md
- **Testing**: Build locally with `docker build -t local/{service}:latest .` before pushing