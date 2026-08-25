#!/bin/bash
# 00-misc-scripts.sh - Miscellaneous initialization tasks

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_script_start "00-misc-scripts.sh"

export PATH="/usr/local/mariadb/bin:/usr/local/mariadb/scripts:$PATH"

log_script_end "00-misc-scripts.sh"