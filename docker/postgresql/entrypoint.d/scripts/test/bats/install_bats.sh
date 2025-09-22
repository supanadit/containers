#!/bin/bash
# install_bats.sh - Install BATS testing framework
# Downloads and installs BATS for shell script testing

# Set error handling
set -euo pipefail

# BATS version to install
BATS_VERSION="1.10.0"
BATS_URL="https://github.com/bats-core/bats-core/archive/v${BATS_VERSION}.tar.gz"
BATS_SUPPORT_URL="https://github.com/bats-core/bats-support/archive/v0.3.0.tar.gz"
BATS_ASSERT_URL="https://github.com/bats-core/bats-assert/archive/v2.0.0.tar.gz"
INSTALL_DIR="/opt/bats"

# Main function
main() {
    echo "Installing BATS testing framework v$BATS_VERSION"

    # Check if already installed
    if command -v bats >/dev/null 2>&1; then
        echo "BATS is already installed: $(bats --version)"
        return 0
    fi

    # Install dependencies
    install_dependencies

    # Download and install BATS
    download_and_install_bats

    # Verify installation
    verify_installation

    echo "BATS installation completed successfully"
}

# Install required dependencies
install_dependencies() {
    echo "Installing dependencies..."

    # Update package list
    apt-get update

    # Install required packages
    apt-get install -y \
        curl \
        tar \
        git \
        build-essential \
        bash

    echo "Dependencies installed"
}

# Download and install BATS
download_and_install_bats() {
    echo "Downloading BATS v$BATS_VERSION..."

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)

    cd "$temp_dir"

    # Download BATS
    curl -L "$BATS_URL" -o "bats-${BATS_VERSION}.tar.gz"

    # Extract
    tar -xzf "bats-${BATS_VERSION}.tar.gz"

    # Build and install
    cd "bats-core-${BATS_VERSION}"

    echo "Building BATS..."
    ./install.sh "$INSTALL_DIR"

    # Download and install bats-support
    echo "Installing bats-support..."
    cd "$temp_dir"
    curl -L "$BATS_SUPPORT_URL" -o "bats-support.tar.gz"
    tar -xzf "bats-support.tar.gz"
    mkdir -p "$INSTALL_DIR/lib"
    cp -r "bats-support-"* "$INSTALL_DIR/lib/bats-support"

    # Download and install bats-assert
    echo "Installing bats-assert..."
    curl -L "$BATS_ASSERT_URL" -o "bats-assert.tar.gz"
    tar -xzf "bats-assert.tar.gz"
    cp -r "bats-assert-"* "$INSTALL_DIR/lib/bats-assert"

    # Create test_helper symlinks for each test directory
    echo "Creating test_helper symlinks..."
    for test_dir in unit integration performance; do
        if [ -d "/opt/container/entrypoint.d/scripts/test/$test_dir" ]; then
            mkdir -p "/opt/container/entrypoint.d/scripts/test/$test_dir/test_helper"
            ln -sf "$INSTALL_DIR/lib/bats-support" "/opt/container/entrypoint.d/scripts/test/$test_dir/test_helper/"
            ln -sf "$INSTALL_DIR/lib/bats-assert" "/opt/container/entrypoint.d/scripts/test/$test_dir/test_helper/"
        fi
    done

    # Add to PATH
    export PATH="$INSTALL_DIR/bin:$PATH"

    # Clean up
    cd /
    rm -rf "$temp_dir"

    echo "BATS and support libraries installed to: $INSTALL_DIR"
}

# Verify installation
verify_installation() {
    echo "Verifying BATS installation..."

    # Check if bats command is available
    if ! command -v bats >/dev/null 2>&1; then
        echo "ERROR: BATS command not found after installation"
        exit 1
    fi

    # Check version
    local installed_version
    installed_version=$(bats --version | grep -oP '\d+\.\d+\.\d+' || echo "unknown")

    if [ "$installed_version" != "$BATS_VERSION" ]; then
        echo "WARNING: Installed version ($installed_version) differs from expected ($BATS_VERSION)"
    fi

    echo "BATS v$installed_version is working correctly"
}

# Execute main function
main "$@"