#!/bin/bash
set -e

CASSANDRA_VERSION=${CASSANDRA_VERSION:-5.0.5}
CASSANDRA_HOME=${CASSANDRA_HOME:-/opt/cassandra}

echo "=== Installing Apache Cassandra ${CASSANDRA_VERSION} ==="

# Download Cassandra
wget -q https://downloads.apache.org/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz

# Extract Cassandra
tar -xzf apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz
mv apache-cassandra-${CASSANDRA_VERSION} ${CASSANDRA_HOME}

# Clean up downloaded file
rm apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz

# Set permissions
chmod +x ${CASSANDRA_HOME}/bin/*.sh

echo "=== Cassandra installed successfully ==="