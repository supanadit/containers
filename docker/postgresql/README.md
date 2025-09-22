# PostgreSQL Container

A Docker container providing PostgreSQL database with Patroni clustering, pgBackRest backup, and comprehensive monitoring capabilities.

## Features

- **PostgreSQL 13.5** with extensions (Citus, pg_stat_monitor, decoderbufs)
- **Patroni clustering** for high availability
- **pgBackRest** for backup and recovery
- **Modular architecture** with maintainable scripts
- **Comprehensive testing** with BATS framework
- **Security hardening** and permission management
- **Health monitoring** and performance metrics
- **✅ Production Ready** - Fully functional with docker-compose

## Quick Start

### Basic Usage

```bash
# Run PostgreSQL directly
docker run postgres-container

# Run with Patroni clustering
docker run -e USE_PATRONI=true postgres-container

# Maintenance mode
docker run -e SLEEP_MODE=true postgres-container
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PGDATA` | `/usr/local/pgsql/data` | PostgreSQL data directory |
| `PGCONFIG` | `/usr/local/pgsql/config` | Configuration directory |
| `LOG_LEVEL` | `INFO` | Logging verbosity (DEBUG, INFO, WARN, ERROR) |
| `USE_PATRONI` | `false` | Enable Patroni clustering |
| `SLEEP_MODE` | `false` | Enable maintenance mode |
| `BACKUP_ENABLED` | `false` | Enable pgBackRest backups |
| `TIMEOUT` | `30` | Default timeout in seconds |

### Custom Configuration

```bash
# Custom postgresql.conf
docker run -v /my/config/postgresql.conf:/usr/local/pgsql/config/postgresql.conf postgres-container

# Custom environment
docker run -e POSTGRESQL_SHARED_BUFFERS=512MB -e LOG_LEVEL=DEBUG postgres-container
```

## Architecture

### Directory Structure

```
containers/docker/postgresql/
├── Dockerfile                    # Container build definition
├── entrypoint.sh                # Main container orchestrator
├── setup.sh                     # Build-time setup script
├── setup/                       # Build-time setup scripts
│   └── scripts/                 # Installation scripts
├── entrypoint.d/                # Runtime entrypoint scripts
│   ├── entrypoint.sh            # Main orchestrator
│   └── scripts/                 # Modular scripts
│       ├── utils/               # Shared utilities
│       │   ├── logging.sh       # Structured logging
│       │   ├── validation.sh    # Configuration validation
│       │   └── security.sh      # Security hardening
│       ├── init/                # Initialization scripts
│       │   ├── 01-directories.sh # Directory setup
│       │   ├── 02-database.sh    # Database cluster init
│       │   ├── 03-config.sh      # Configuration management
│       │   └── 04-backup.sh      # Backup system setup
│       ├── runtime/             # Runtime management
│       │   ├── startup.sh        # Process startup logic
│       │   ├── shutdown.sh       # Graceful shutdown
│       │   └── healthcheck.sh    # Health monitoring
│       └── test/                # Testing infrastructure
│           ├── run_tests.sh      # Test execution script
│           ├── bats/            # BATS testing framework
│           ├── unit/            # Unit tests
│           ├── integration/     # Integration tests
│           ├── performance/     # Performance tests
│           └── fixtures/        # Test data and mocks
```

### Script Execution Flow

1. **Entrypoint** (`entrypoint.sh`)
   - Load utility functions
   - Validate environment
   - Set up signal handlers

2. **Initialization** (in order)
   - `01-directories.sh`: Create required directories
   - `02-database.sh`: Initialize PostgreSQL cluster
   - `03-config.sh`: Generate/manage configurations
   - `04-backup.sh`: Configure pgBackRest

3. **Runtime** (`startup.sh`)
   - Select startup mode (direct/Patroni/sleep)
   - Start PostgreSQL processes
   - Handle process management

4. **Shutdown** (`shutdown.sh`)
   - Graceful termination (30s timeout)
   - Resource cleanup
   - Force kill if necessary

## Testing

### Run All Tests

```bash
# Inside container
/opt/container/entrypoint.d/scripts/test/run_tests.sh

# Or via Docker
docker run --rm postgres-container /opt/container/entrypoint.d/scripts/test/run_tests.sh
```

### Test Categories

- **Unit Tests**: Individual script function testing
- **Integration Tests**: End-to-end container scenarios
- **Performance Tests**: Startup/shutdown time validation

### Test Framework

Tests use the [BATS](https://github.com/bats-core/bats-core) framework:

```bash
# Install BATS (if not already installed)
/opt/container/entrypoint.d/scripts/test/bats/install_bats.sh

# Run specific test
bats /opt/container/entrypoint.d/scripts/test/unit/test_script_interfaces.bats
```

## Configuration

### PostgreSQL Settings

Override via environment variables:

```bash
POSTGRESQL_SHARED_BUFFERS=256MB
POSTGRESQL_MAX_CONNECTIONS=200
POSTGRESQL_WORK_MEM=4MB
POSTGRESQL_LISTEN_ADDRESSES=0.0.0.0
```

### Patroni Configuration

Generated automatically when `USE_PATRONI=true`:

- Cluster scope: `postgres-cluster`
- REST API: `0.0.0.0:8008`
- etcd integration for DCS

### Backup Configuration

Enabled with `BACKUP_ENABLED=true`:

- pgBackRest stanza: `default`
- Backup retention: 2 full, 6 differential
- Archive command integration

## Health Monitoring

### Health Check Endpoint

```bash
# Check overall health
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh

# Check specific aspects
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh postgresql
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh patroni
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh disk
```

### Health Indicators

- **PostgreSQL connectivity**: Database accepting connections
- **Patroni status**: Cluster management health
- **Disk space**: Sufficient storage available
- **Process health**: All required processes running

## Security

### Security Features

- **Non-root execution**: PostgreSQL runs as dedicated user
- **Secure permissions**: 644 for configs, 700 for data
- **Input validation**: All environment variables validated
- **Secure defaults**: Restrictive configuration templates

### Security Hardening

- File permissions automatically set
- Sensitive data not logged
- Secure temporary file creation
- Audit logging for security events

## Performance

### Performance Targets

- **Startup time**: < 30 seconds
- **Shutdown time**: < 30 seconds (graceful)
- **Initialization**: < 10 seconds
- **Health check**: < 1 second

### Resource Usage

- **Memory**: < 50MB additional overhead
- **Disk**: < 10MB for scripts and logs
- **CPU**: Minimal additional load

## Troubleshooting

### Common Issues

#### Container Won't Start

```bash
# Check logs
docker logs <container_id>

# Enable debug logging
docker run -e LOG_LEVEL=DEBUG postgres-container

# Check environment validation
docker exec <container_id> /opt/container/entrypoint.d/scripts/utils/validation.sh validate_environment
```

#### Permission Errors

```bash
# Check current permissions
docker exec <container_id> ls -la /usr/local/pgsql/

# Fix permissions
docker exec <container_id> /opt/container/entrypoint.d/scripts/utils/security.sh set_secure_permissions /usr/local/pgsql/data
```

#### Configuration Not Applied

```bash
# Validate configuration
docker exec <container_id> /opt/container/entrypoint.d/scripts/utils/validation.sh validate_config_files

# Check config file location
docker exec <container_id> ls -la /usr/local/pgsql/config/
```

#### Database Connection Issues

```bash
# Test connectivity
docker exec <container_id> /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh postgresql

# Check PostgreSQL logs
docker exec <container_id> tail -f /usr/local/pgsql/log/postgresql.log
```

### Debug Mode

```bash
# Enter maintenance mode for debugging
docker run -e SLEEP_MODE=true --entrypoint /bin/bash postgres-container

# Run individual components
/opt/container/entrypoint.d/scripts/init/01-directories.sh
/opt/container/entrypoint.d/scripts/runtime/startup.sh
```

## Development

### Adding New Features

1. **Identify script category**:
   - Utility function → `utils/`
   - Initialization step → `init/`
   - Runtime behavior → `runtime/`

2. **Follow contracts**:
   - Use provided interfaces
   - Include proper error handling
   - Add logging and validation

3. **Add tests**:
   - Unit tests for functions
   - Integration tests for scenarios
   - Performance tests for timing

### Code Standards

- **POSIX compliance**: Shell scripts compatible with dash/bash
- **Error handling**: `set -euo pipefail`
- **Documentation**: Comments for complex logic
- **Testing**: Comprehensive test coverage

## Migration from Legacy Container

### Backward Compatibility

The enhanced container maintains **100% backward compatibility**:

- All existing environment variables work
- Mount points function identically
- Command-line arguments preserved
- Network configurations unchanged

### Performance Impact

- **Startup time**: < 5% increase
- **Memory usage**: < 10MB additional
- **Disk usage**: < 5MB additional

### Migration Steps

1. **Test in staging**: Deploy to non-production first
2. **Monitor performance**: Validate against targets
3. **Gradual rollout**: Replace legacy containers
4. **Rollback plan**: Keep legacy image available

## Support

### Getting Help

1. Check container logs: `docker logs <container_id>`
2. Run diagnostics: `/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh`
3. Review documentation: This README and inline script comments
4. Check test output: `/opt/container/entrypoint.d/scripts/test/run_tests.sh`

### Reporting Issues

Include in bug reports:
- Docker version and platform
- Container logs with `LOG_LEVEL=DEBUG`
- Environment variables used
- Custom configurations mounted
- Expected vs actual behavior
- Test failure output

## Changelog

### v1.0.0 (Current)
- Modular script architecture
- Comprehensive testing framework
- Enhanced security hardening
- Performance monitoring
- Backward compatibility maintained
- ✅ **Docker Compose Support** - Fixed daemon mode and graceful shutdown
- ✅ **Process Management** - Added pgrep and process monitoring tools