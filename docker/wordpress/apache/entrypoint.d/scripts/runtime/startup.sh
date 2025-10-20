#!/bin/bash
# startup.sh - Start the WordPress application

set -euo pipefail

# Source utilities
source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Starting WordPress application"

# Execute the main command (typically Apache)
exec "$@"