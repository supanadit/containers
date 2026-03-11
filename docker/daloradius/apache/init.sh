#!/bin/bash
set -e

DALORADIUS_PATH=/var/www/daloradius
DALORADIUS_CONF_PATH=$DALORADIUS_PATH/app/common/includes/daloradius.conf.php

echo "=========================================="
echo "daloRADIUS Container Initialization"
echo "=========================================="

# 1. Copy sample config if not exists
if [ ! -f "$DALORADIUS_CONF_PATH" ] || [ ! -s "$DALORADIUS_CONF_PATH" ]; then
    echo "[INFO] Copying sample config file..."
    cp "$DALORADIUS_CONF_PATH.sample" "$DALORADIUS_CONF_PATH"
    chown www-data:www-data "$DALORADIUS_CONF_PATH"
else
    echo "[INFO] Config file already exists, skipping..."
fi

# 2. Configure database using sed (official approach)
echo "[INFO] Configuring database settings..."

[ -n "$MYSQL_HOST" ] && sed -i "s/\$configValues\['CONFIG_DB_HOST'\] = .*/\$configValues['CONFIG_DB_HOST'] = '$MYSQL_HOST';/" $DALORADIUS_CONF_PATH
[ -n "$MYSQL_PORT" ] && sed -i "s/\$configValues\['CONFIG_DB_PORT'\] = .*/\$configValues['CONFIG_DB_PORT'] = '$MYSQL_PORT';/" $DALORADIUS_CONF_PATH
[ -n "$MYSQL_USER" ] && sed -i "s/\$configValues\['CONFIG_DB_USER'\] = .*/\$configValues['CONFIG_DB_USER'] = '$MYSQL_USER';/" $DALORADIUS_CONF_PATH

# Use MYSQL_PASSWORD or fall back to MYSQL_ROOT_PASSWORD
if [ -n "$MYSQL_PASSWORD" ]; then
    sed -i "s/\$configValues\['CONFIG_DB_PASS'\] = .*/\$configValues['CONFIG_DB_PASS'] = '$MYSQL_PASSWORD';/" $DALORADIUS_CONF_PATH
elif [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    sed -i "s/\$configValues\['CONFIG_DB_PASS'\] = .*/\$configValues['CONFIG_DB_PASS'] = '$MYSQL_ROOT_PASSWORD';/" $DALORADIUS_CONF_PATH
fi

[ -n "$MYSQL_DATABASE" ] && sed -i "s/\$configValues\['CONFIG_DB_NAME'\] = .*/\$configValues['CONFIG_DB_NAME'] = '$MYSQL_DATABASE';/" $DALORADIUS_CONF_PATH

# Set FreeRADIUS version
sed -i "s/\$configValues\['FREERADIUS_VERSION'\] = .*/\$configValues['FREERADIUS_VERSION'] = '3';/" $DALORADIUS_CONF_PATH

# Set log file location
sed -i "s|\$configValues\['CONFIG_LOG_FILE'\] = .*|\$configValues['CONFIG_LOG_FILE'] = '/tmp/daloradius.log';|" $DALORADIUS_CONF_PATH

echo "[INFO] Database configuration completed"

# 3. Create log files and directories
echo "[INFO] Setting up log files..."
touch /tmp/daloradius.log
chown www-data:www-data /tmp/daloradius.log
mkdir -p /usr/local/apache2/logs/daloradius
chown www-data:www-data /usr/local/apache2/logs/daloradius

# 4. Wait for MySQL
MYSQL_CREDS="${MYSQL_USER:-root}:${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}"
echo -n "[INFO] Waiting for MySQL ($MYSQL_HOST)..."

until mysqladmin ping -h"$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" -u"${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" --silent 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo " OK"

# 5. Initialize database if needed
DB_LOCK=/data/.db_init_done
if [ ! -f "$DB_LOCK" ]; then
    echo "[INFO] Checking database tables..."

    # Try to connect and check if operators table exists
    if ! mysql -h "$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" "${MYSQL_DATABASE:-radius}" -e "SELECT 1 FROM operators LIMIT 1" 2>/dev/null; then
        echo "[INFO] Importing daloRADIUS schema..."
        
        # Import FreeRADIUS schema
        if [ -f "$DALORADIUS_PATH/contrib/db/fr3-mariadb-freeradius.sql" ]; then
            mysql -h "$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" "${MYSQL_DATABASE:-radius}" < "$DALORADIUS_PATH/contrib/db/fr3-mariadb-freeradius.sql" 2>/dev/null || true
        fi
        
        # Import daloRADIUS schema
        if [ -f "$DALORADIUS_PATH/contrib/db/mariadb-daloradius.sql" ]; then
            mysql -h "$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" "${MYSQL_DATABASE:-radius}" < "$DALORADIUS_PATH/contrib/db/mariadb-daloradius.sql" 2>/dev/null || true
        fi
        
        echo "[INFO] Database schema imported"
    else
        echo "[INFO] Database tables already exist, skipping import..."
    fi
    
    date > "$DB_LOCK"
else
    echo "[INFO] Database already initialized, skipping..."
fi

# 6. Set permissions
echo "[INFO] Setting permissions..."
chown -R www-data:www-data /var/www/daloradius
chmod -R 755 /var/www/daloradius

# 7. Start Apache
echo "[INFO] Starting Apache..."
echo "=========================================="
echo "daloRADIUS is ready!"
echo "=========================================="

/usr/local/apache2/bin/httpd -D FOREGROUND
