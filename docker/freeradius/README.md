# FreeRADIUS

This container provides a production-ready FreeRADIUS server with easy configuration through environment variables.

## Usage

### Build

```bash
docker build -t ghcr.io/supanadit/containers/freeradius:3.2.8 .
```

### Run

```bash
docker run -d \
  --name freeradius \
  -p 1812:1812/udp \
  -p 1813:1813/udp \
  ghcr.io/supanadit/containers/freeradius:3.2.8
```

### Test Authentication

```bash
radtest admin admin localhost 1812 secret
```

### Volumes

- `/usr/local/freeradius/etc/raddb` - Configuration directory
- `/usr/local/freeradius/log` - Log directory

## Environment Variables

### Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIUS_LISTEN_ADDR` | `*` | Listen address (e.g., `*`, `0.0.0.0`, `127.0.0.1`) |
| `RADIUS_AUTH_PORT` | `1812` | Authentication port (UDP) |
| `RADIUS_ACCT_PORT` | `1813` | Accounting port (UDP) |
| `RADIUS_STATUS_PORT` | (disabled) | Status port for health checks |
| `RADIUS_TIMEOUT` | `30` | Request timeout in seconds |
| `RADIUS_MAX_REQUEST` | `4096` | Maximum requests the server keeps track of |
| `RADIUS_MAX_ATTRIBUTES` | `200` | Maximum attributes per RADIUS packet |

### Client Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIUS_DEFAULT_SECRET` | `secret` | Default shared secret for clients |
| `RADIUS_CLIENTS` | - | Add clients via env var (format: `name:ip:secret` or `ip:secret`, comma-separated) |
| `RADIUS_CLIENT_NETWORK` | - | Add client network (format: `cidr:secret`) |

**Example - Adding clients:**
```bash
docker run -d \
  -e RADIUS_CLIENTS="wifi-ap:192.168.1.10:ap_secret,vpn-gateway:10.0.0.1:vpn_secret" \
  ghcr.io/supanadit/containers/freeradius:3.2.8
```

### Default User

| Variable | Default | Description |
|----------|---------|-------------|
| `FREERADIUS_USER_NAME` | `admin` | Default username |
| `FREERADIUS_USER_PASSWORD` | `admin` | Default password |

**WARNING:** Default credentials are `admin/admin`. Change these in production!

### Authentication Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIUS_AUTH_TYPE` | `files` | Authentication type: `files`, `sql`, `ldap`, `pam` |

### SQL Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_ENABLE` | `false` | Enable SQL backend (`true`/`false`) |
| `DB_TYPE` | `mysql` | Database type: `mysql`, `postgresql`, `sqlite` |
| `DB_HOST` | `localhost` | Database host |
| `DB_PORT` | `3306` | Database port |
| `DB_NAME` | `radius` | Database name |
| `DB_USER` | `radius` | Database username |
| `DB_PASS` | - | Database password |
| `DB_POOL_MAX` | `20` | Maximum connections in pool |

**Example - MySQL backend:**
```bash
docker run -d \
  -e RADIUS_AUTH_TYPE=sql \
  -e DB_ENABLE=true \
  -e DB_HOST=mysql \
  -e DB_NAME=radius \
  -e DB_USER=radius \
  -e DB_PASS=radpass \
  ghcr.io/supanadit/containers/freeradius:3.2.8
```

### LDAP Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `LDAP_ENABLE` | `false` | Enable LDAP backend (`true`/`false`) |
| `LDAP_SERVER` | - | LDAP server URL (e.g., `ldap://ldap.example.com`) |
| `LDAP_PORT` | `389` | LDAP port |
| `LDAP_IDENTITY` | - | LDAP bind DN |
| `LDAP_PASSWORD` | - | LDAP bind password |
| `LDAP_BASE_DN` | - | LDAP base DN |

**Example - LDAP backend:**
```bash
docker run -d \
  -e RADIUS_AUTH_TYPE=ldap \
  -e LDAP_ENABLE=true \
  -e LDAP_SERVER=ldap://ldap.example.com \
  -e LDAP_BASE_DN=dc=example,dc=com \
  -e LDAP_IDENTITY=cn=admin,dc=example,dc=com \
  -e LDAP_PASSWORD=adminpass \
  ghcr.io/supanadit/containers/freeradius:3.2.8
```

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIUS_DEBUG` | `no` | Enable debug mode (`yes`/`no`) |
| `RADIUS_LOG_LEVEL` | `info` | Log level: `debug`, `info`, `warn`, `error` |
| `FREERADIUS_TIMEZONE` | `UTC` | Timezone |

### Runtime

| Variable | Default | Description |
|----------|---------|-------------|
| `SLEEP_MODE` | `false` | Enable maintenance mode (`true`/`false`) |

When `SLEEP_MODE=true`, the container runs without starting FreeRADIUS - useful for maintenance tasks.

### Health Check

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIUS_HOST` | `127.0.0.1` | Health check host |
| `HEALTH_CHECK_SECRET` | `secret` | Secret for status check |
| `HEALTH_CHECK_MAX_ATTEMPTS` | `3` | Max retry attempts |
| `HEALTH_CHECK_ATTEMPT_INTERVAL` | `1` | Interval between attempts (seconds) |

## Adding Users via Environment

Users can be added using the `RADIUS_USERS` environment variable:

```bash
docker run -d \
  -e RADIUS_USERS="user1:pass1,user2:pass2" \
  ghcr.io/supanadit/containers/freeradius:3.2.8
```

Format: `username:password` (comma-separated for multiple users)

## Testing

### Test Authentication
```bash
docker run -d --name freeradius ghcr.io/supanadit/containers/freeradius:3.2.8

# From another container or host
radtest admin admin localhost 1812 secret
```

### Test Accounting
```bash
radtest -x admin admin localhost 1813 secret
```

## Production Notes

1. **Change default credentials:**
   ```bash
   docker run -d \
     -e FREERADIUS_USER_PASSWORD=your_secure_password \
     ghcr.io/supanadit/containers/freeradius:3.2.8
   ```

2. **Change default client secret:**
   ```bash
   docker run -d \
     -e RADIUS_DEFAULT_SECRET=your_secure_secret \
     ghcr.io/supanadit/containers/freeradius:3.2.8
   ```

3. **Use custom configuration:**
   Mount your own configuration directory:
   ```bash
   docker run -d \
     -v /path/to/raddb:/usr/local/freeradius/etc/raddb \
     ghcr.io/supanadit/containers/freeradius:3.2.8
   ```

4. **Enable debug mode for troubleshooting:**
   ```bash
   docker run -d \
     -e RADIUS_DEBUG=yes \
     ghcr.io/supanadit/containers/freeradius:3.2.8
   ```
