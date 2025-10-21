#!/bin/bash
set -e

# Set environment variables
export CASSANDRA_HOME=/opt/cassandra
export PATH=/opt/cassandra/bin:$PATH

# Set Java options for Cassandra
export JVM_OPTS="-Xms1g -Xmx1g"

# Start Cassandra
echo "Starting Apache Cassandra..."
exec cassandra -f