#!/bin/bash

set -e

# Create wp-config.php if it doesn't exist in /content
if [ ! -f /content/wp-config.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" /var/www/html/wp-config.php
    sed -i "s/username_here/${WORDPRESS_DB_USER}/" /var/www/html/wp-config.php
    sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" /var/www/html/wp-config.php
    sed -i "s/localhost/${WORDPRESS_DB_HOST}/" /var/www/html/wp-config.php

    # Only replace salts if placeholders are present
    if grep -q "put your unique phrase here" /var/www/html/wp-config.php; then
        SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
        awk -v salts="$SALTS" '
            BEGIN {replaced=0}
            /define\(.*_KEY.*\)|define\(.*_SALT.*\)/ {
                if (!replaced) {
                    print salts
                    replaced=1
                }
                next
            }
            {print}
        ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    fi

    mv /var/www/html/wp-config.php /content/wp-config.php
    chown www-data:www-data /content/wp-config.php
fi

# If wp-config.php exists in /content, copy it to /var/www/html
if [ -f /content/wp-config.php ]; then
    ln -sf /content/wp-config.php /var/www/html/wp-config.php
    chown www-data:www-data /var/www/html/wp-config.php
fi

# If IS_STATELESS only symlink wp-content/uploads
if [ "$IS_STATELESS" = "true" ]; then

    # Create directory uploads if it doesn't exist in /content
    if [ ! -d /content/uploads ]; then
        mkdir -p /content/uploads
        chown www-data:www-data /content/uploads
        chmod -R 777 /content/uploads
    fi

    ln -s /content/uploads /var/www/html/wp-content/uploads
else
    # Create symlink for all wp-content directories but first we need copy to /content
    if [ ! -d /content/wp-content ]; then
        mkdir -p /content/wp-content
        cp -r /var/www/html/wp-content/* /content/wp-content/
    fi

    if [ -d /var/www/html/wp-content ]; then
        rm -rf /var/www/html/wp-content
        ln -s /content/wp-content /var/www/html
        chown -R www-data:www-data /var/www/html/wp-content
    fi

    # Set 777 permissions wp-content directory
    # I have no idea how to set proper permissions for wp-content directory
    # Some plugins doesn't wont running for example redis-object-cache
    chmod -R 777 /var/www/html/wp-content
fi

exec "$@"