#!/bin/bash
set -e

echo "=== Building and installing Java ==="

# Use JAVA_VERSION from environment or default to 21
JAVA_VERSION=${JAVA_VERSION:-21}

echo "Installing Amazon Corretto JDK ${JAVA_VERSION}"

# Create temp directory
mkdir -p /temp/sources
cd /temp/sources

# Download Amazon Corretto JDK
CORRETTO_URL="https://corretto.aws/downloads/latest/amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.tar.gz"
echo "Downloading from ${CORRETTO_URL}"
curl -L -o corretto.tar.gz "${CORRETTO_URL}"

# Extract JDK
tar -xzf corretto.tar.gz
JDK_DIR=$(tar -tf corretto.tar.gz | head -1 | cut -d'/' -f1)

# Move to /opt
mv "${JDK_DIR}" /opt/java

# Set JAVA_HOME
export JAVA_HOME=/opt/java
echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment

# Add to PATH
export PATH="${JAVA_HOME}/bin:${PATH}"
echo "PATH=${JAVA_HOME}/bin:\${PATH}" >> /etc/environment

# Verify installation
java -version

echo "=== Java installed successfully ==="