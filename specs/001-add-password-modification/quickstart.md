# Quickstart: postgresql

## Container Overview
PostgreSQL database container with high availability support via Patroni, backup capabilities with pgBackRest, and horizontal scaling with Citus. This container includes password modification on first startup using the POSTGRES_PASSWORD environment variable.

## Prerequisites
- Docker 20.10+ or container runtime
- 1GB RAM minimum, 2GB recommended
- 2GB disk space for data volume
- Network access for package downloads during build

## Quick Start Commands

### Basic PostgreSQL Instance
```bash
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e TIMEOUT_CHANGE_PASSWORD=10 \
  -v postgres_data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgresql:latest
```

### With Custom Configuration
```bash
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_DB=mydb \
  -v postgres_data:/var/lib/postgresql/data \
  -v postgres_config:/etc/postgresql/custom.conf.d \
  -p 5432:5432 \
  postgresql:latest
```

### High Availability with Patroni
```bash
docker run -d \
  --name postgres-ha \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e PATRONI_NAME=node1 \
  -e PATRONI_SCOPE=cluster1 \
  -v postgres_data:/var/lib/postgresql/data \
  -p 5432:5432 \
  -p 8008:8008 \
  postgresql:latest
```

## Environment Variables

### Required
- **POSTGRES_PASSWORD**: Database superuser password

### Optional
- **TIMEOUT_CHANGE_PASSWORD**: Password modification timeout (default: 5 seconds)
- **POSTGRES_USER**: Database superuser username (default: postgres)
- **POSTGRES_DB**: Default database name (default: postgres)
- **PGDATA**: Data directory (default: /var/lib/postgresql/data)

## Volume Mounts

### Required
- **/var/lib/postgresql/data**: Persistent data storage

### Optional
- **/etc/postgresql/custom.conf.d**: Custom configuration files
- **/var/lib/pgbackrest**: Backup storage

## Networking

### Ports
- **5432**: PostgreSQL client connections
- **8008**: Patroni REST API (HA mode)

### Network Modes
- **bridge**: Default, exposes ports on host
- **host**: Direct host networking (not recommended for production)
- **overlay**: For Docker Swarm orchestration

## Health Checks

The container includes built-in health checks:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start Period**: 60 seconds
- **Retries**: 3

Monitor health with:
```bash
docker ps
# Look for STATUS "healthy"
```

## Logging

### Log Access
```bash
docker logs postgres
```

### Log Configuration
- Structured JSON format
- Configurable log levels
- PostgreSQL logs in /var/log/postgresql/

## Backup and Recovery

### Using pgBackRest
```bash
# Inside container
pgbackrest backup
pgbackrest restore
```

### Volume Backup
```bash
docker run --rm \
  -v postgres_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

## Troubleshooting

### Common Issues

**Container fails to start**
- Check POSTGRES_PASSWORD is set
- Verify volume permissions
- Check available disk space

**Connection refused**
- Verify port 5432 is exposed and not in use
- Check firewall settings
- Confirm POSTGRES_PASSWORD is correct

**Health check fails**
- Wait for initial startup (60 seconds)
- Check PostgreSQL logs
- Verify data volume is accessible

### Debug Mode
```bash
docker run -it --rm \
  -e POSTGRES_PASSWORD=debug \
  -v postgres_data:/var/lib/postgresql/data \
  postgresql:latest \
  bash
```

## Performance Tuning

### Resource Limits
```bash
docker run -d \
  --memory=1g \
  --cpus=1 \
  --name postgres \
  # ... other options
```

### PostgreSQL Configuration
Mount custom configuration:
```bash
-v ./postgresql.conf:/etc/postgresql/custom.conf.d/custom.conf
```

## Security Considerations

- Change default POSTGRES_PASSWORD in production
- Use Docker secrets for sensitive environment variables
- Regularly update base images
- Monitor for security vulnerabilities
- Restrict network access to necessary ports only

## Migration from Other PostgreSQL Containers

### From Official PostgreSQL
1. Backup existing data
2. Stop old container
3. Start new container with same volume
4. Set POSTGRES_PASSWORD to migrate password

### Data Migration
```bash
# Export from old container
pg_dumpall -h old_host -U postgres > backup.sql

# Import to new container
psql -h new_host -U postgres < backup.sql
```