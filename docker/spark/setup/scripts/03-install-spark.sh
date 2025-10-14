#!/bin/bash
set -e

echo "=== Building and installing Spark ==="

# Set environment variables
export JAVA_HOME=/opt/java
export PATH="${JAVA_HOME}/bin:${PATH}"

# Use SPARK_VERSION from environment or default
SPARK_VERSION=${SPARK_VERSION:-4.0.1}
HADOOP_VERSION=${HADOOP_VERSION:-3}

echo "Installing Apache Spark ${SPARK_VERSION}"

# Create temp directory
mkdir -p /temp/sources
cd /temp/sources

# Download Spark
SPARK_URL="https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
echo "Downloading from ${SPARK_URL}"
wget "${SPARK_URL}"

# Extract Spark
tar -xzf "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
SPARK_DIR="spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}"

# Move to /opt
mv "${SPARK_DIR}" /opt/spark

# Set SPARK_HOME
export SPARK_HOME=/opt/spark
echo "SPARK_HOME=${SPARK_HOME}" >> /etc/environment

# Add to PATH
export PATH="${SPARK_HOME}/bin:${PATH}"
echo "PATH=${SPARK_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
/opt/spark/bin/spark-submit --version

echo "=== Spark installed successfully ==="