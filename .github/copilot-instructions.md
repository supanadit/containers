# Containers Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-09-22

## Active Technologies
- Shell scripting (Bash) for container scripts
- PostgreSQL 13.5, Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0
- Docker containerization
- Linux environment
- Bash 5.1 (scripts), Dockerfile + PostgreSQL 13.5, Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0, decoderbufs (002-reduce-build-time)
- PostgreSQL database (002-reduce-build-time)

## Project Structure
```
containers/
├── docker/                         # Docker containers directory
│   ├── postgresql/                 # PostgreSQL container
│   │   ├── Dockerfile              # Container build definition
│   │   ├── entrypoint.sh          # Main container orchestrator
│   │   ├── setup.sh               # Build-time setup script
│   │   ├── setup/                 # Build-time setup scripts
│   │   │   └── scripts/           # Installation scripts
│   │   │       ├── 01-install-dependencies.sh
│   │   │       ├── 02-install-postgresql.sh
│   │   │       ├── 03-install-python.sh
│   │   │       ├── 04-install-pgbackrest.sh
│   │   │       ├── 05-install-citus.sh
│   │   │       ├── 06-install-pgstatmonitor.sh
│   │   │       ├── 07-install-decoderbufs.sh
│   │   │       ├── 08-install-patroni.sh
│   │   │       └── 09-cleanup.sh
│   │   └── entrypoint.d/           # Entrypoint scripts directory
│   │       ├── scripts/            # Runtime container scripts
│   │       │   ├── utils/          # Shared utility functions
│   │       │   │   ├── logging.sh    # Structured logging
│   │       │   │   ├── validation.sh # Configuration validation
│   │       │   │   └── security.sh   # Security hardening
│   │       │   ├── init/           # Initialization scripts
│   │       │   │   ├── 01-directories.sh # Directory setup
│   │       │   │   ├── 02-database.sh    # Database cluster init
│   │       │   │   ├── 03-config.sh      # Configuration management
│   │       │   │   └── 04-backup.sh      # Backup system setup
│   │       │   ├── runtime/        # Runtime management
│   │       │   │   ├── startup.sh    # Process startup logic
│   │       │   │   ├── shutdown.sh   # Graceful shutdown
│   │       │   │   └── healthcheck.sh # Health monitoring
│   │       │   └── test/           # Testing infrastructure
│   │       │       ├── run_tests.sh  # Test execution script
│   │       │       ├── bats/        # BATS testing framework
│   │       │       ├── unit/        # Unit tests
│   │       │       ├── integration/ # Integration tests
│   │       │       └── fixtures/    # Test data and mocks
│   │       └── entrypoint.sh        # Main container orchestrator
│   ├── grafana/                    # Grafana container
│   ├── prometheus/                 # Prometheus container
│   └── etcd/                       # etcd container
└── specs/                         # Feature specifications
    └── 001-enhance-existing-postgresql/
        ├── spec.md                # Feature requirements
        ├── plan.md               # Implementation plan
        ├── research.md           # Technical research
        ├── data-model.md         # Script architecture
        ├── quickstart.md         # Developer guide
        └── contracts/            # Interface contracts
```

## Commands
```bash
# Build container
docker build -t postgres-container .

# Run with default settings
docker run postgres-container

# Run with Patroni
docker run -e USE_PATRONI=true postgres-container

# Run in maintenance mode
docker run -e SLEEP_MODE=true postgres-container

# Debug mode with verbose logging
docker run -e LOG_LEVEL=DEBUG postgres-container

# Test container functionality
docker run --rm postgres-container /opt/container/scripts/test/run_tests.sh
```

## Code Style
Shell scripting: Follow POSIX standards, use `set -e` for error handling, document functions, use structured logging, validate inputs, handle errors gracefully, maintain security best practices.

## Recent Changes
- 002-reduce-build-time: Added Bash 5.1 (scripts), Dockerfile + PostgreSQL 13.5, Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0, decoderbufs
- 001-enhance-existing-postgresql: Split monolithic entrypoint.sh into modular, maintainable scripts while adding comprehensive testing coverage

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
