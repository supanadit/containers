# containers Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-09-26

## Active Technologies
- Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0, decoderbufs v3.2.2.Final, Python v3.11.2 (002-allow-external-connection)

## Project Structure
```
src/
tests/
```

## Commands
# Add commands for 

## Code Style
- Follow standard conventions
- **Docker Compose**: Do not use the `version` property in `docker-compose.yml` or `docker-compose.yaml` files as it has been deprecated since Docker Compose v1.27.0. The Compose file format is now automatically determined by the Docker Compose version being used.

## Recent Changes
- 002-allow-external-connection: Added Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0, decoderbufs v3.2.2.Final, Python v3.11.2

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->