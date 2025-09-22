# Quickstart: PostgreSQL Build Optimization

## Overview
This guide helps developers build the PostgreSQL container efficiently, minimizing rebuild times when modifying entrypoint scripts.

## Prerequisites
- Docker 20.10+ with BuildKit enabled
- Git repository cloned
- Basic understanding of Docker builds

## Quick Build Commands

### Standard Build (with caching)
```bash
# Enable BuildKit for better caching
export DOCKER_BUILDKIT=1

# Build with optimized caching
docker build -t postgres-optimized docker/postgresql/
```

### Development Build (frequent entrypoint changes)
```bash
# Build once initially
docker build -t postgres-dev docker/postgresql/

# Modify entrypoint.d scripts...
# Rebuild only changes layers
docker build -t postgres-dev docker/postgresql/
```

### Debug Build (verbose output)
```bash
# See build steps and cache usage
docker build --progress=plain -t postgres-debug docker/postgresql/
```

## Understanding Build Optimization

### Layer Structure
1. **Setup Layer**: Dependencies, PostgreSQL installation (changes rarely)
2. **Entrypoint Layer**: Runtime scripts, configuration (changes frequently)

### Cache Behavior
- **Cache Hit**: Reuses unchanged layers (green in build output)
- **Cache Miss**: Rebuilds from changed layer onward
- **Optimal**: Only entrypoint changes trigger minimal rebuilds

## Development Workflow

### 1. Initial Setup
```bash
cd /path/to/containers
git checkout 002-reduce-build-time
```

### 2. First Build
```bash
docker build -t postgres-dev docker/postgresql/
# This takes longer as it builds all layers
```

### 3. Iterative Development
```bash
# Edit entrypoint.d/scripts/startup.sh
vim docker/postgresql/entrypoint.d/scripts/runtime/startup.sh

# Rebuild - only entrypoint layer rebuilds
docker build -t postgres-dev docker/postgresql/

# Verify cache efficiency
docker build --progress=plain -t postgres-dev docker/postgresql/ | grep -E "(CACHED|RUN|COPY)"
```

### 4. Testing Changes
```bash
# Run with your changes
docker run -d --name postgres-test postgres-dev

# Check logs
docker logs postgres-test

# Health check
docker exec postgres-test /opt/container/scripts/healthcheck.sh

# Cleanup
docker stop postgres-test && docker rm postgres-test
```

## Troubleshooting

### Build Taking Too Long?
- Check if setup scripts changed (triggers full rebuild)
- Verify .dockerignore excludes unnecessary files
- Use `docker build --no-cache` only when needed

### Cache Not Working?
- Files copied in wrong order in Dockerfile
- .dockerignore including necessary files
- Base image changed

### Runtime Issues?
- Check entrypoint script permissions
- Verify setup layer completed successfully
- Review container logs for errors

## Performance Benchmarks

### Expected Build Times
- **Full rebuild**: 10-15 minutes
- **Entrypoint changes**: 1-2 minutes
- **Setup changes**: 10-15 minutes (full rebuild)

### Monitoring Performance
```bash
# Time a build
time docker build -t postgres-bench docker/postgresql/

# Check image size
docker images postgres-bench

# Analyze layers
docker history postgres-bench
```

## Advanced Usage

### Multi-Platform Builds
```bash
# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t postgres-multi docker/postgresql/
```

### CI/CD Integration
```bash
# Build with labels
docker build \
  --label "org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  -t postgres-ci docker/postgresql/
```

## Next Steps
- Review the implementation plan for detailed design
- Check contracts for interface specifications
- Run tests to validate functionality