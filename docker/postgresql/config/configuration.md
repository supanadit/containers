# Configuration Design: PostgreSQL External Access

## Environment Variables
- **EXTERNAL_ACCESS_ENABLE**: true/false (default: true) - Enable external connections
- **EXTERNAL_ACCESS_METHOD**: md5 (default: md5) - Authentication method for external connections
- **POSTGRESQL_PORT**: 5432 (existing) - Port to expose
- **POSTGRESQL_HOST**: localhost (existing) - Internal host

## Volume Mount Points
- /var/lib/postgresql/data: PostgreSQL data directory
- /etc/postgresql/: Config files (if needed)

## Data Persistence Strategy
- PostgreSQL data persisted in named volume
- Config changes via env vars, not persisted

## Port Exposure and Network Requirements
- Port 5432 exposed to 0.0.0.0/0 when EXTERNAL_ACCESS_ENABLE=true
- Internal networking for Patroni cluster

## Health Check Implementation
- Command: healthcheck.sh script
- Interval: 30s
- Timeout: 10s
- Retries: 3

## Logging Configuration
- Structured JSON format
- Levels: INFO, WARN, ERROR
- Output: stdout/stderr
- External connection logs: INFO level

## Signal Handling and Graceful Shutdown
- SIGTERM: Trigger Patroni shutdown
- PostgreSQL fast shutdown
- Cleanup connections before exit

## Resource Limits and Requirements
- Memory: <1GB
- CPU: <1 core
- Disk: <2GB for image + data volumes