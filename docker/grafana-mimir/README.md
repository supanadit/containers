# Grafana Mimir

This image packages Grafana Mimir in single binary mode for local experimentation. The container downloads the upstream release archive during build, extracts the binary to `/usr/share/grafana/mimir`, and ships with a sample configuration at `/etc/mimir-sample.yaml`.

## Usage

```bash
# Build
cd docker/grafana-mimir
podman build -t grafana-mimir .

# Run with the sample configuration mounted for edits
mkdir -p $(pwd)/config
podman run \
  -p 9009:9009 \
  -v $(pwd)/config:/config \
  grafana-mimir
```

Configuration is copied to `/config/mimir.yaml` on first start. Override the configuration path with `GRAFANA_MIMIR_CONFIG` or append extra CLI flags via `GRAFANA_MIMIR_EXTRA_ARGS`.
