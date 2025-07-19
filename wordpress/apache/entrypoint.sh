#!/bin/bash

set -e

# Create wp-config.php if it doesn't exist in /content
if [ ! -f /content/wp-config.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" /var/www/html/wp-config.php
    sed -i "s/username_here/${WORDPRESS_DB_USER}/" /var/www/html/wp-config.php
    sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" /var/www/html/wp-config.php
    sed -i "s/localhost/${WORDPRESS_DB_HOST}/" /var/www/html/wp-config.php

    # Fetch and inject salts
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    awk -v salts="$SALTS" '
        /put your unique phrase here/ {print salts; next}
        {print}
    ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php

    mv /var/www/html/wp-config.php /content/wp-config.php
    chown www-data:www-data /content/wp-config.php
    # Copy wp-config.php to /var/www/html
    cp /content/wp-config.php /var/www/html/wp-config.php
    chown www-data:www-data /var/www/html/wp-config.php
fi

# Create directory uploads if it doesn't exist in /content
if [ ! -d /content/uploads ]; then
    mkdir -p /content/uploads
    chown www-data:www-data /content/uploads
    chmod -R 777 /content/uploads
    # Symlink uploads to /var/www/html
    ln -s /content/uploads /var/www/html/wp-content/uploads
fi

exec "$@"