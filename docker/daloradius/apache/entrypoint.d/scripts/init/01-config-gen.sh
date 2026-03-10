#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

log_info "Generating daloRADIUS configuration"

# Set defaults
DALORADIUS_DB_HOST="${DALORADIUS_DB_HOST:-mysql}"
DALORADIUS_DB_USER="${DALORADIUS_DB_USER:-radius}"
DALORADIUS_DB_PASS="${DALORADIUS_DB_PASS:-radius}"
DALORADIUS_DB_NAME="${DALORADIUS_DB_NAME:-radius}"
DALORADIUS_DB_PORT="${DALORADIUS_DB_PORT:-3306}"
DALORADIUS_FREERADIUS_VERSION="${DALORADIUS_FREERADIUS_VERSION:-3}"

# Check if config already exists
CONFIG_FILE="/var/www/html/daloradius/library/daloradius.conf.php"

if [ -f "$CONFIG_FILE" ]; then
    log_info "Configuration file already exists, backing up and regenerating"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
fi

# Generate the configuration file
cat > "$CONFIG_FILE" << EOF
<?php
/*
 * daloRADIUS Configuration File
 * Generated automatically from environment variables
 */

\$configValues['DALORADIUS_VERSION'] = '1.3';
\$configValues['FREERADIUS_VERSION'] = '${DALORADIUS_FREERADIUS_VERSION}';
\$configValues['CONFIG_DB_ENGINE'] = 'mysqli';
\$configValues['CONFIG_DB_HOST'] = '${DALORADIUS_DB_HOST}';
\$configValues['CONFIG_DB_PORT'] = '${DALORADIUS_DB_PORT}';
\$configValues['CONFIG_DB_USER'] = '${DALORADIUS_DB_USER}';
\$configValues['CONFIG_DB_PASS'] = '${DALORADIUS_DB_PASS}';
\$configValues['CONFIG_DB_NAME'] = '${DALORADIUS_DB_NAME}';

// table names
\$configValues['CONFIG_DB_TBL_RADCHECK'] = 'radcheck';
\$configValues['CONFIG_DB_TBL_RADREPLY'] = 'radreply';
\$configValues['CONFIG_DB_TBL_RADACCT'] = 'radacct';
\$configValues['CONFIG_DB_TBL_RADGROUPREPLY'] = 'radgroupreply';
\$configValues['CONFIG_DB_TBL_RADGROUPCHECK'] = 'radgroupcheck';
\$configValues['CONFIG_DB_TBL_RADUSERGROUP'] = 'radusergroup';
\$configValues['CONFIG_DB_TBL_DALOOPERATORS'] = 'operators';
\$configValues['CONFIG_DB_TBL_DALOOPERATORS_ACL'] = 'operators_acl';
\$configValues['CONFIG_DB_TBL_DALORATES'] = 'rates';
\$configValues['CONFIG_DB_TBL_DALOHOTSPOTS'] = 'nas';
\$configValues['CONFIG_DB_TBL_DALOUSERINFO'] = 'userinfo';
\$configValues['CONFIG_DB_TBL_DALOUSERBILLINFO'] = 'userbillinfo';
\$configValues['CONFIG_DB_TBL_DALORADPOSTAUTH'] = 'radpostauth';
\$configValues['CONFIG_DB_TBL_DALORADACCT'] = 'radacct';
\$configValues['CONFIG_DB_TBL_DALONODE'] = 'nodes';
\$configValues['CONFIG_DB_TBL_DALOUSERREPLY'] = 'userreply';
\$configValues['CONFIG_DB_TBL_DALOUSERGROUPREPLY'] = 'usergroupreply';

// Debugging
\$configValues['CONFIG_DEBUG_ENABLED'] = false;
\$configValues['CONFIG_DEBUG_LEVEL'] = 3;

// Language
\$configValues['CONFIG_LANG'] = 'en';

// Billing
\$configValues['CONFIG_BILLING_DATE_FORMAT'] = 'Y-m-d';

// Invoice and Report settings
\$configValues['CONFIG_INVOICE_ENABLE'] = false;
\$configValues['CONFIG_INVOICE_TEMPLATE'] = 'invoice_template.html';
\$configValues['CONFIG_INVOICE_ITEM_TEMPLATE'] = 'invoice_item_template.html';

// FreeRADIUS Dictionary
\$configValues['FREERADIUS_VERSION'] = '${DALORADIUS_FREERADIUS_VERSION}';
\$configValues['DALORADIUS_VERSION'] = '1.3';

// Application name
\$configValues['APP_NAME'] = 'daloRADIUS';
\$configValues['APP_TITLE'] = 'daloRADIUS - RADIUS Management';

?>
EOF

chown www-data:www-data "$CONFIG_FILE"
chmod 644 "$CONFIG_FILE"

log_info "Configuration file generated successfully"
log_info "Database: ${DALORADIUS_DB_HOST}:${DALORADIUS_DB_PORT}/${DALORADIUS_DB_NAME}"
log_info "FreeRADIUS Version: ${DALORADIUS_FREERADIUS_VERSION}"
