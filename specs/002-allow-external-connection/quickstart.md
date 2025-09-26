# Quickstart: PostgreSQL with External Access

## Basic Usage
```bash
docker run -d \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```
Default: External access enabled with md5 auth.

## Disable External Access
```bash
docker run -d \
  -e EXTERNAL_ACCESS_ENABLE=false \
  -e POSTGRESQL_PASSWORD=mypassword \
  postgresql:latest
```

## Custom Authentication Method
```bash
docker run -d \
  -e EXTERNAL_ACCESS_METHOD=password \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```

## With Data Persistence
```bash
docker run -d \
  -v postgres_data:/var/lib/postgresql/data \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```

## Health Check
```bash
docker exec container_id /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh
```

## Troubleshooting
- If connections fail: Check EXTERNAL_ACCESS_ENABLE=true
- Invalid method: Falls back to md5, check logs
- Port not accessible: Ensure -p 5432:5432</content>
<parameter name="filePath">/home/supanadit/Workspaces/Personal/Docker/containers/specs/002-allow-external-connection/quickstart.md