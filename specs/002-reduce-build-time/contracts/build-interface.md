# Contract: Build Interface

## Overview
This contract defines the Dockerfile structure and build process interface for optimized caching and consistent builds.

## Dockerfile Structure Contract

### Required Stages
```dockerfile
# Build stage (optional, for complex builds)
FROM base-image AS builder
# Build dependencies and artifacts

# Setup stage
FROM base-image AS setup
# Install system dependencies
# Install application dependencies
# Create necessary directories

# Runtime stage
FROM base-image AS runtime
# Copy setup results
# Copy entrypoint scripts
# Set runtime configuration
```

### Layer Ordering Requirements
1. **Base Image**: FROM statement
2. **System Dependencies**: apt-get, yum, etc.
3. **Application Installation**: PostgreSQL, Patroni, etc.
4. **Directory Creation**: mkdir, chown
5. **Stable Files Copy**: setup scripts, config templates
6. **Volatile Files Copy**: entrypoint scripts, runtime configs
7. **Permissions**: chmod, chown
8. **Cleanup**: Remove caches, temp files

### COPY Command Specifications
```dockerfile
# Early copies (stable files)
COPY setup/scripts/ /opt/container/setup/scripts/
COPY config/ /opt/container/config/

# Late copies (volatile files)
COPY entrypoint.sh /opt/container/
COPY entrypoint.d/ /opt/container/entrypoint.d/
```

### Environment Variables Contract
- All configuration via ENV
- No hardcoded values
- Documented default values
- Validation at runtime

### User Contract
- Non-root execution by default
- Configurable user ID
- Proper file permissions

## Build Context Contract

### .dockerignore Requirements
```
# Exclude development files
.git/
.github/
specs/
*.md
!README.md

# Exclude build artifacts
**/target/
**/build/
**/.cache/

# Include only necessary files
docker/postgresql/
!docker/postgresql/.gitkeep
```

### Build Arguments
- VERSION: Application version
- BUILD_DATE: Build timestamp
- VCS_REF: Git commit hash

## Runtime Interface Contract

### Entrypoint Requirements
- Must be executable script
- Must handle signals properly
- Must provide health checks
- Must log startup/shutdown

### Health Check Contract
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/scripts/healthcheck.sh
```

### Volume Contract
- Define persistent volumes
- Document volume purposes
- Set proper permissions

## Testing Contract

### Build Tests
- Multi-stage build validation
- Layer cache effectiveness
- Image size optimization
- Security scanning

### Runtime Tests
- Container startup time
- Health check functionality
- Configuration validation
- Resource usage limits