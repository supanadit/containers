# Containers Repository

This repository is a monorepo for various containers. We have `docker` directories for docker build, we might also have another directory for `podman`, `buildah`, etc in the future.

## Guidelines

- **Docker Compose**: Do not use the `version` property in `docker-compose.yml` or `docker-compose.yaml` files as it has been deprecated since Docker Compose v1.27.0. The Compose file format is now automatically determined by the Docker Compose version being used.