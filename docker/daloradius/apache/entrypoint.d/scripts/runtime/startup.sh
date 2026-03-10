#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Starting Apache HTTP Server"

# Set PATH
export PATH="/usr/local/apache2/bin:$PATH"

# Start Apache in foreground
exec /usr/local/apache2/bin/httpd -D FOREGROUND
