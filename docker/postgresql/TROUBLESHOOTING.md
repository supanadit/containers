# PostgreSQL Container Troubleshooting Guide

This guide provides solutions for common issues with the PostgreSQL container, organized by symptom and root cause.

## Quick Diagnosis

### Health Check Command

```bash
# Run comprehensive health check
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh

# Check specific components
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh postgresql
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh patroni
/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh disk
```

### Debug Mode

```bash
# Enable debug logging
docker run -e LOG_LEVEL=DEBUG postgres-container

# Enter maintenance mode for investigation
docker run -e SLEEP_MODE=true --entrypoint /bin/bash postgres-container
```

## Container Startup Issues

### Symptom: Container exits immediately

**Possible Causes:**
1. Environment validation failure
2. Directory permission issues
3. Configuration file errors

**Diagnosis:**
```bash
# Check exit code
docker inspect <container_id> | grep -A 5 "State"

# View logs
docker logs <container_id>
```

**Solutions:**

1. **Environment Validation Error**
   ```bash
   # Validate environment variables
   docker run --rm -e LOG_LEVEL=DEBUG postgres-container /opt/container/entrypoint.d/scripts/utils/validation.sh validate_environment
   ```

2. **Permission Issues**
   ```bash
   # Check directory permissions
   docker run --rm postgres-container ls -la /usr/local/pgsql/

   # Fix permissions
   docker run --rm postgres-container /opt/container/entrypoint.d/scripts/utils/security.sh set_secure_permissions /usr/local/pgsql/data
   ```

3. **Configuration Errors**
   ```bash
   # Validate configuration files
   docker run --rm postgres-container /opt/container/entrypoint.d/scripts/utils/validation.sh validate_config_files
   ```

### Symptom: Container hangs during startup

**Possible Causes:**
1. Database initialization taking too long
2. Network connectivity issues
3. Resource constraints

**Diagnosis:**
```bash
# Check running processes
docker exec <container_id> ps aux

# Monitor startup logs
docker logs -f <container_id>
```

**Solutions:**

1. **Database Initialization**
   ```bash
   # Check if PostgreSQL is starting
   docker exec <container_id> /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh postgresql

   # Force timeout and check logs
   docker logs <container_id> | grep -i "timeout\|error"
   ```

2. **Resource Issues**
   ```bash
   # Check memory usage
   docker stats <container_id>

   # Increase memory limit
   docker run -m 1g postgres-container
   ```

## PostgreSQL Connection Issues

### Symptom: Cannot connect to database

**Possible Causes:**
1. PostgreSQL not running
2. Authentication configuration
3. Network binding issues

**Diagnosis:**
```bash
# Check if PostgreSQL is running
docker exec <container_id> ps aux | grep postgres

# Test local connection
docker exec <container_id> su - postgres -c "psql -c 'SELECT version();'"
```

**Solutions:**

1. **PostgreSQL Not Started**
   ```bash
   # Check startup logs
   docker logs <container_id> | grep -A 10 -B 10 "starting postgresql"

   # Manual start attempt
   docker exec <container_id> /opt/container/entrypoint.d/scripts/runtime/startup.sh
   ```

2. **Authentication Issues**
   ```bash
   # Check pg_hba.conf
   docker exec <container_id> cat /usr/local/pgsql/config/pg_hba.conf

   # Test with different credentials
   docker exec <container_id> su - postgres -c "psql -U postgres -c 'SELECT 1;'"
   ```

3. **Network Binding**
   ```bash
   # Check postgresql.conf listen_addresses
   docker exec <container_id> grep listen_addresses /usr/local/pgsql/config/postgresql.conf

   # Test port binding
   docker exec <container_id> netstat -tlnp | grep 5432
   ```

### Symptom: Connection refused

**Diagnosis:**
```bash
# Check container networking
docker inspect <container_id> | grep -A 10 "NetworkSettings"

# Test port accessibility
docker exec <container_id> nc -zv localhost 5432
```

**Solutions:**

1. **Port Not Exposed**
   ```bash
   # Run with port mapping
   docker run -p 5432:5432 postgres-container
   ```

2. **Firewall Issues**
   ```bash
   # Check host firewall
   sudo ufw status

   # Allow PostgreSQL port
   sudo ufw allow 5432
   ```

## Patroni Clustering Issues

### Symptom: Patroni not starting

**Possible Causes:**
1. etcd connectivity issues
2. Configuration conflicts
3. Resource constraints

**Diagnosis:**
```bash
# Check Patroni logs
docker logs <container_id> | grep patroni

# Test etcd connectivity
docker exec <container_id> /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh patroni
```

**Solutions:**

1. **etcd Connection**
   ```bash
   # Check etcd endpoint
   docker exec <container_id> curl -f http://etcd:2379/health

   # Verify etcd configuration in patroni.yml
   docker exec <container_id> cat /usr/local/pgsql/config/patroni.yml
   ```

2. **Configuration Conflicts**
   ```bash
   # Validate Patroni config
   docker exec <container_id> patroni --validate-config /usr/local/pgsql/config/patroni.yml
   ```

### Symptom: Cluster not forming

**Diagnosis:**
```bash
# Check cluster status
docker exec <container_id> curl -s http://localhost:8008/cluster | jq .

# Check member status
docker exec <container_id> curl -s http://localhost:8008/patroni | jq .
```

**Solutions:**

1. **Network Issues**
   ```bash
   # Ensure containers can communicate
   docker network ls
   docker network inspect <network_name>
   ```

2. **Configuration Mismatch**
   ```bash
   # Compare configurations across nodes
   docker exec <container_id> cat /usr/local/pgsql/config/patroni.yml | grep scope
   ```

## Backup and Recovery Issues

### Symptom: pgBackRest backup fails

**Possible Causes:**
1. Storage permission issues
2. Configuration errors
3. Repository connectivity

**Diagnosis:**
```bash
# Check pgBackRest logs
docker logs <container_id> | grep pgbackrest

# Test backup configuration
docker exec <container_id> pgbackrest info
```

**Solutions:**

1. **Permission Issues**
   ```bash
   # Check backup directory permissions
   docker exec <container_id> ls -la /var/lib/pgbackrest/

   # Fix permissions
   docker exec <container_id> chown postgres:postgres /var/lib/pgbackrest/
   ```

2. **Configuration Errors**
   ```bash
   # Validate pgBackRest config
   docker exec <container_id> pgbackrest --config /usr/local/pgsql/config/pgbackrest.conf info
   ```

## Performance Issues

### Symptom: Slow startup times

**Diagnosis:**
```bash
# Measure startup time
time docker run --rm postgres-container /opt/container/entrypoint.d/scripts/test/performance/test_startup_time.bats

# Check resource usage
docker stats <container_id>
```

**Solutions:**

1. **Resource Constraints**
   ```bash
   # Increase CPU allocation
   docker run --cpus 2 postgres-container

   # Increase memory
   docker run -m 2g postgres-container
   ```

2. **Disk I/O Issues**
   ```bash
   # Use faster storage
   docker run -v /fast/ssd/postgres:/usr/local/pgsql/data postgres-container
   ```

### Symptom: High memory usage

**Diagnosis:**
```bash
# Monitor memory usage
docker stats <container_id>

# Check PostgreSQL memory settings
docker exec <container_id> grep shared_buffers /usr/local/pgsql/config/postgresql.conf
```

**Solutions:**

1. **Tune PostgreSQL Memory**
   ```bash
   # Adjust memory settings
   docker run -e POSTGRESQL_SHARED_BUFFERS=256MB postgres-container
   ```

2. **Monitor for Leaks**
   ```bash
   # Check for connection leaks
   docker exec <container_id> su - postgres -c "psql -c 'SELECT count(*) FROM pg_stat_activity;'"
   ```

## Disk Space Issues

### Symptom: Container running out of disk space

**Diagnosis:**
```bash
# Check disk usage
docker exec <container_id> df -h

# Check PostgreSQL data size
docker exec <container_id> du -sh /usr/local/pgsql/data/
```

**Solutions:**

1. **Clean Up Logs**
   ```bash
   # Rotate PostgreSQL logs
   docker exec <container_id> /opt/container/entrypoint.d/scripts/utils/logging.sh rotate_logs

   # Clean old backups
   docker exec <container_id> pgbackrest expire --repo1 --set 20220101-000000F
   ```

2. **Increase Disk Space**
   ```bash
   # Use larger volume
   docker run -v /large/disk/postgres:/usr/local/pgsql/data postgres-container
   ```

## Security Issues

### Symptom: Permission denied errors

**Diagnosis:**
```bash
# Check file permissions
docker exec <container_id> ls -la /usr/local/pgsql/

# Check running user
docker exec <container_id> whoami
```

**Solutions:**

1. **Fix Permissions**
   ```bash
   # Run security hardening
   docker exec <container_id> /opt/container/entrypoint.d/scripts/utils/security.sh set_secure_permissions /usr/local/pgsql/data
   ```

2. **User Context Issues**
   ```bash
   # Ensure running as correct user
   docker exec <container_id> id
   ```

## Testing and Validation Issues

### Symptom: Tests failing

**Diagnosis:**
```bash
# Run tests with verbose output
docker run --rm postgres-container /opt/container/entrypoint.d/scripts/test/run_tests.sh -v

# Check specific test failure
docker run --rm postgres-container bats /opt/container/entrypoint.d/scripts/test/integration/test_startup.bats
```

**Solutions:**

1. **Environment Issues**
   ```bash
   # Check test environment
   docker run --rm postgres-container env | grep -E "(PGDATA|LOG_LEVEL)"

   # Validate test fixtures
   docker run --rm postgres-container ls -la /opt/container/entrypoint.d/scripts/test/fixtures/
   ```

2. **Dependency Issues**
   ```bash
   # Check BATS installation
   docker run --rm postgres-container which bats

   # Reinstall if needed
   docker run --rm postgres-container /opt/container/entrypoint.d/scripts/test/bats/install_bats.sh
   ```

## Advanced Debugging

### Debug Scripts

```bash
# Enable script debugging
docker run -e LOG_LEVEL=DEBUG -e SCRIPT_DEBUG=true postgres-container

# Step through initialization
docker run -e SLEEP_MODE=true --entrypoint /bin/bash postgres-container -c "
  source /opt/container/entrypoint.d/scripts/utils/logging.sh
  source /opt/container/entrypoint.d/scripts/utils/validation.sh
  /opt/container/entrypoint.d/scripts/init/01-directories.sh
"
```

### Log Analysis

```bash
# Extract error patterns
docker logs <container_id> | grep -i error | tail -10

# Check timing issues
docker logs <container_id> | grep -E "(timeout|starting|finished)" | tail -20

# Monitor resource usage over time
docker stats <container_id> --no-stream | head -20
```

### Network Debugging

```bash
# Test internal connectivity
docker exec <container_id> ping -c 3 etcd

# Check DNS resolution
docker exec <container_id> nslookup etcd

# Test service discovery
docker exec <container_id> curl -s http://localhost:8008/config | jq .
```

## Emergency Procedures

### Force Shutdown

```bash
# Graceful shutdown with timeout
docker stop --time 30 <container_id>

# Force kill if needed
docker kill <container_id>
```

### Data Recovery

```bash
# Backup current state
docker cp <container_id>:/usr/local/pgsql/data /host/backup/location

# Restore from backup
docker run -v /host/backup/location:/usr/local/pgsql/data postgres-container
```

### Clean Restart

```bash
# Remove container and volumes
docker rm -f <container_id>
docker volume rm <volume_name>

# Fresh start
docker run --name fresh-postgres postgres-container
```

## Getting Help

### Information to Include in Bug Reports

1. **Container Information**
   ```bash
   docker version
   docker inspect <container_id> | jq '.Config.Image'
   ```

2. **Environment Details**
   ```bash
   docker run --rm postgres-container env | grep -v PATH
   ```

3. **Complete Logs**
   ```bash
   docker logs <container_id> > container_logs.txt
   ```

4. **System Resources**
   ```bash
   docker stats <container_id> --no-stream
   df -h
   free -h
   ```

### Support Checklist

- [ ] Container logs collected
- [ ] Environment variables documented
- [ ] Docker version noted
- [ ] System resources checked
- [ ] Test case to reproduce issue
- [ ] Expected vs actual behavior described

## Prevention

### Best Practices

1. **Regular Monitoring**
   ```bash
   # Set up health checks
   docker run --health-cmd="/opt/container/entrypoint.d/scripts/runtime/healthcheck.sh" postgres-container
   ```

2. **Resource Planning**
   ```bash
   # Monitor usage trends
   docker stats <container_id> --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
   ```

3. **Backup Strategy**
   ```bash
   # Regular backups
   docker exec <container_id> pgbackrest backup --type incr
   ```

4. **Log Rotation**
   ```bash
   # Prevent log disk usage
   docker run -v /host/logs:/usr/local/pgsql/log postgres-container
   ```