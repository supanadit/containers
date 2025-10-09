# PgPool-II Container

A Docker container for PgPool-II that provides connection pooling and load balancing for multiple PostgreSQL instances.

## Features

- **Load Balancing**: Distribute queries across multiple PostgreSQL backends
- **Connection Pooling**: Efficient connection management to reduce overhead
- **Health Monitoring**: Automatic health checks for backend PostgreSQL instances
- **Flexible Configuration**: Environment variable-based configuration
- **Multi-Backend Support**: Support for multiple PostgreSQL instances with different weights and flags

## Quick Start

### Using Docker Run

```bash
docker run -d \
  --name pgpool \
  -p 5432:5432 \
  -p 9898:9898 \
  -e PGPOOL_BACKENDS="172.10.10.5:5432,172.10.10.6:5432,172.10.10.7:5432" \
  -e PGPOOL_BACKEND_WEIGHTS="1,1,1" \
  -e PGPOOL_LOAD_BALANCE_MODE="on" \
  supanadit/pgpool-ii:4.6.3
```

### Using Docker Compose

See `docker-compose.example.yml` for a complete example with multiple PostgreSQL backends.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PGPOOL_BACKENDS` | Comma-separated list of PostgreSQL backends | `"host1:5432,host2:5432,host3:5432"` |

### Optional Variables

#### Backend Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_BACKEND_WEIGHTS` | `"1,1,1,..."` | Comma-separated weights for load balancing |
| `PGPOOL_BACKEND_FLAGS` | `"ALLOW_TO_FAILOVER,..."` | Comma-separated flags for each backend |

#### Connection Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_PORT` | `5432` | PgPool-II listening port |
| `PGPOOL_PCP_PORT` | `9898` | PCP (PgPool Control Protocol) port |

#### Pool Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_NUM_INIT_CHILDREN` | `32` | Number of pre-forked child processes |
| `PGPOOL_MAX_POOL` | `4` | Maximum connections per child process |
| `PGPOOL_CHILD_LIFE_TIME` | `300` | Child process lifetime in seconds |
| `PGPOOL_CONNECTION_LIFE_TIME` | `0` | Connection lifetime in seconds (0 = unlimited) |
| `PGPOOL_CHILD_MAX_CONNECTIONS` | `0` | Maximum connections per child (0 = unlimited) |

#### Load Balancing
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_LOAD_BALANCE_MODE` | `on` | Enable/disable load balancing |
| `PGPOOL_IGNORE_LEADING_WHITE_SPACE` | `on` | Ignore leading whitespace in SQL |

#### Health Check
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_HEALTH_CHECK_TIMEOUT` | `20` | Health check timeout in seconds |
| `PGPOOL_HEALTH_CHECK_PERIOD` | `0` | Health check interval in seconds (0 = disabled) |
| `PGPOOL_HEALTH_CHECK_USER` | `postgres` | User for health checks |

#### Authentication
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_ENABLE_POOL_HBA` | `off` | Enable pool_hba.conf authentication |
| `PGPOOL_POOL_PASSWD` | `pool_passwd` | Password file name |

#### Advanced Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `PGPOOL_CONFIG_DIR` | `/usr/local/pgpool/etc` | Configuration directory |
| `PGPOOL_LOG_DIR` | `/var/log/pgpool` | Log directory |
| `PGPOOL_RUN_DIR` | `/var/run/pgpool` | Runtime directory |
| `PGPOOL_USER` | `postgres` | User to run PgPool-II as |
| `PGPOOL_DEBUG` | `false` | Enable debug logging |

## Usage Examples

### Basic Load Balancing

```bash
docker run -d \
  --name pgpool \
  -p 5432:5432 \
  -e PGPOOL_BACKENDS="db1.example.com:5432,db2.example.com:5432" \
  supanadit/pgpool-ii:4.6.3
```

### Weighted Load Balancing

```bash
docker run -d \
  --name pgpool \
  -p 5432:5432 \
  -e PGPOOL_BACKENDS="primary:5432,replica1:5432,replica2:5432" \
  -e PGPOOL_BACKEND_WEIGHTS="3,1,1" \
  supanadit/pgpool-ii:4.6.3
```

### With Health Monitoring

```bash
docker run -d \
  --name pgpool \
  -p 5432:5432 \
  -e PGPOOL_BACKENDS="db1:5432,db2:5432,db3:5432" \
  -e PGPOOL_HEALTH_CHECK_PERIOD="30" \
  -e PGPOOL_HEALTH_CHECK_TIMEOUT="10" \
  -e PGPOOL_HEALTH_CHECK_USER="healthcheck" \
  supanadit/pgpool-ii:4.6.3
```

## Connecting to PgPool-II

Once running, connect to PgPool-II as you would to a regular PostgreSQL instance:

```bash
# Using psql
psql -h localhost -p 5432 -U myuser -d mydb

# Using connection string
postgresql://myuser:mypass@localhost:5432/mydb
```

## Administration

PgPool-II provides a control protocol (PCP) for administration:

```bash
# Show pool status
pcp_pool_status -h localhost -p 9898 -U postgres

# Show backend nodes
pcp_node_info -h localhost -p 9898 -U postgres

# Detach a backend node
pcp_detach_node -h localhost -p 9898 -U postgres -n 1
```

## Health Check

The container includes a health check script that monitors PgPool-II status. You can also check manually:

```bash
# Check if PgPool-II is running
docker exec pgpool ps aux | grep pgpool

# Check logs
docker logs pgpool
```

## Troubleshooting

### Common Issues

1. **Connection refused**: Check if backends are accessible from the container
2. **Authentication failed**: Verify PostgreSQL user credentials and authentication method
3. **Load balancing not working**: Ensure `PGPOOL_LOAD_BALANCE_MODE=on` and queries are load-balanceable

### Debug Mode

Enable debug logging for troubleshooting:

```bash
docker run -d \
  --name pgpool \
  -e PGPOOL_DEBUG="true" \
  -e PGPOOL_BACKENDS="..." \
  supanadit/pgpool-ii:4.6.3
```

### Logs

View container logs:

```bash
docker logs -f pgpool
```

## Building

To build the container:

```bash
docker build -t supanadit/pgpool-ii:4.6.3 docker/pgpool-ii
```

## Version

- PgPool-II: 4.6.3
- Base Image: Debian Bookworm
- Container Version: 1.0.0