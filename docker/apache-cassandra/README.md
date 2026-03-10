# Apache Cassandra

This container provides Apache Cassandra, a highly scalable, high-performance distributed database designed to handle large amounts of data across many commodity servers.

## Features

- Apache Cassandra 5.0.5
- Single-node setup for development/testing
- CQL (Cassandra Query Language) support
- Configurable via environment variables

## Usage

### Build

```bash
docker build -t supanadit/cassandra:5.0.5 .
```

### Run

```bash
docker run -p 9042:9042 supanadit/cassandra:5.0.5
```

Connect using CQLSH:
```bash
docker exec -it <container_id> cqlsh
```

### Volumes

- `/opt/cassandra/data` - Data directory
- `/opt/cassandra/logs` - Logs directory
- `/opt/cassandra/commitlog` - Commit log directory

## Environment Variables

- `CASSANDRA_VERSION` - Cassandra version to install (default: 5.0.5)
- `CASSANDRA_HOME` - Cassandra home directory (default: /opt/cassandra)
- `JVM_OPTS` - JVM options for Cassandra (default: -Xms1g -Xmx1g)

## Ports

- `7000` - Internode communication (not exposed by default)
- `7001` - TLS internode communication (not exposed by default)
- `7199` - JMX monitoring
- `9042` - CQL client port
- `9160` - Thrift client API (deprecated)