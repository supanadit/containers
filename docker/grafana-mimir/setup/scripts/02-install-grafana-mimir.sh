#!/bin/bash
set -euo pipefail

echo "=== Installing Grafana Mimir ==="

TMP_DIR="/tmp/downloads"
DIST_DIR="${TMP_DIR}/mimir-dist"
INSTALL_DIR="/usr/share/grafana/mimir"

mkdir -p "${TMP_DIR}" "${INSTALL_DIR}"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# Resolve the current architecture so we download the matching asset.
ARCH_DEB="$(dpkg --print-architecture 2>/dev/null || true)"
if [ -z "${ARCH_DEB}" ]; then
    ARCH_DEB="$(uname -m)"
fi

case "${ARCH_DEB}" in
    amd64|x86_64)
        ARTIFACT_ARCH="amd64"
        ;;
    arm64|aarch64)
        ARTIFACT_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_DEB}" >&2
        exit 1
        ;;
esac

ARTIFACT_BASENAME="mimir-linux-${ARTIFACT_ARCH}"
BASE_URL="https://github.com/grafana/mimir/releases/download/mimir-${GRAFANA_MIMIR_VERSION}"

ARCHIVE_PATH=""
ARCHIVE_NAME=""

# Try known artifact naming patterns in order of most common usage.
for candidate in "${ARTIFACT_BASENAME}" "${ARTIFACT_BASENAME}.tar.gz" "${ARTIFACT_BASENAME}.zip"; do
    TARGET_PATH="${TMP_DIR}/${candidate}"
    if curl -fL --retry 3 --retry-delay 2 -o "${TARGET_PATH}" "${BASE_URL}/${candidate}"; then
        ARCHIVE_PATH="${TARGET_PATH}"
        ARCHIVE_NAME="${candidate}"
        break
    else
        rm -f "${TARGET_PATH}"
    fi
done

if [ -z "${ARCHIVE_PATH}" ]; then
    echo "Failed to download Grafana Mimir ${GRAFANA_MIMIR_VERSION} for architecture ${ARTIFACT_ARCH}" >&2
    exit 1
fi

case "${ARCHIVE_NAME}" in
    *.zip)
        unzip -q "${ARCHIVE_PATH}" -d "${DIST_DIR}"
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "${ARCHIVE_PATH}" -C "${DIST_DIR}"
        ;;
    *)
        install -m 0755 "${ARCHIVE_PATH}" "${INSTALL_DIR}/mimir"
        ;;
esac

if [[ "${ARCHIVE_NAME}" == *.zip || "${ARCHIVE_NAME}" == *.tar.gz || "${ARCHIVE_NAME}" == *.tgz ]]; then
    MIMIR_BIN_PATH="$(find "${DIST_DIR}" -type f -name mimir -print -quit)"
    if [ -z "${MIMIR_BIN_PATH}" ]; then
        echo "Unable to locate the Mimir binary in the downloaded archive" >&2
        exit 1
    fi

    MIMIR_ROOT="$(dirname "${MIMIR_BIN_PATH}")"
    cp -r "${MIMIR_ROOT}/." "${INSTALL_DIR}/"
fi

chmod +x "${INSTALL_DIR}/mimir"

mkdir -p /var/lib/mimir/tsdb
mkdir -p /var/lib/mimir/tsdb-sync
mkdir -p /var/lib/mimir/rules
mkdir -p /var/lib/mimir/alertmanager
mkdir -p /var/lib/mimir/compactor

rm -rf "${DIST_DIR}"
if [ -n "${ARCHIVE_PATH}" ]; then
    rm -f "${ARCHIVE_PATH}"
fi

echo "=== Grafana Mimir installed successfully ==="
