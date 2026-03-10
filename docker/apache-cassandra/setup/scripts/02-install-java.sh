#!/bin/bash
set -e

echo "=== Setting up Java environment ==="

# Set JAVA_HOME if not set
if [ -z "$JAVA_HOME" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    echo "JAVA_HOME set to $JAVA_HOME"
fi

# Verify Java installation
java -version

echo "=== Java environment setup completed ==="