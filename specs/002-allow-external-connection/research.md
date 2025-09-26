# Container Research & Analysis: PostgreSQL External Access

## Base Image Decision
- **Chosen**: debian:bookworm
- **Rationale**: Existing container uses Debian for broad compatibility with PostgreSQL dependencies and Patroni. Provides stable security updates and apt ecosystem.
- **Security**: Regular updates, minimal attack surface with multi-stage builds.
- **Size**: ~100MB base, optimized to <500MB final image.

## Build Strategy
- **Multi-stage Approach**: base → setup → runtime
- **Optimization Techniques**: BuildKit cache mounts for apt, early copying of stable setup scripts, late copying of volatile entrypoint scripts.
- **Layer Caching**: Setup scripts and dependencies cached separately from application code changes.

## Security Approach
- **Hardening Measures**: Non-root postgres user, minimal packages in runtime stage, secure file permissions.
- **User Configuration**: Environment variables for access control without exposing sensitive data.
- **pg_hba.conf Modifications**: Runtime configuration based on env vars, with fallback to secure defaults.

## Configuration Strategy
- **Environment Variables**: EXTERNAL_ACCESS_ENABLE (default true), EXTERNAL_ACCESS_METHOD (default md5)
- **Volumes**: Standard PostgreSQL data volumes, no additional for config.
- **Secrets Management**: No hardcoded credentials, auth methods configurable.
- **Runtime Initialization**: Entrypoint scripts handle pg_hba.conf updates before PostgreSQL startup.

## Monitoring & Health
- **Health Check**: Existing healthcheck.sh script monitors PostgreSQL process and connectivity.
- **Logging**: Structured JSON logging with configurable levels, external connection attempts logged.
- **Observability**: Patroni provides cluster health, pg_stat_monitor for performance metrics.

## Alternatives Considered
- **Base Image**: Alpine considered but rejected due to PostgreSQL dependency complexity and glibc requirements.
- **Access Control**: Hardcoded allow all vs configurable - rejected for security flexibility.
- **Authentication Methods**: Only md5 vs multiple - kept simple with fallback for robustness.</content>
<parameter name="filePath">/home/supanadit/Workspaces/Personal/Docker/containers/specs/002-allow-external-connection/research.md