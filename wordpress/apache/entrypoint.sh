#!/bin/bash

set -e

# Create wp-config.php if it doesn't exist in /content
if [ ! -f /var/www/html/wp-config.php ]; then
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

    if [ ! -f /content/wp-config.php ] && [ "$IS_STATELESS" != "true" ]; then
        cp /var/www/html/wp-config.php /content/wp-config.php
        chown www-data:www-data /content/wp-config.php
    fi
fi

# If wp-config.php exists in /content, copy it to /var/www/html
if [ -f /content/wp-config.php ] && [ "$IS_STATELESS" != "true" ]; then
    ln -sf /content/wp-config.php /var/www/html/wp-config.php
    chown www-data:www-data /var/www/html/wp-config.php
fi

# Handle WORDPRESS_<name> variables
# We will detect all variables that start with WORDPRESS_ and replace them in wp-config.php
# If not exist, we will add them to wp-config.php
# Detect all WORDPRESS_<name> variables
for var in $(compgen -A variable | grep '^WORDPRESS_'); do
    var_name=${var#WORDPRESS_}
    var_value="${!var}"

    # Detect multi-line array/object
    if [[ "$var_value" =~ ^\[ ]] || [[ "$var_value" =~ ^array\( ]]; then
        # Remove trailing newline before ] or )
        cleaned_var_value="$(echo "$var_value" | sed ':a;N;$!ba;s/\n\([])]\)$/\1/')"
        define_stmt="define('$var_name', $cleaned_var_value);"
    # Detect boolean or number
    elif [[ "$var_value" =~ ^(true|false|[0-9]+)$ ]]; then
        define_stmt="define('$var_name', $var_value);"
    else
        define_stmt="define('$var_name', '$var_value');"
    fi

    if grep -q "define('$var_name'" /var/www/html/wp-config.php; then
        awk -v name="$var_name" -v stmt="$define_stmt" '
            BEGIN {replaced=0}
            {
                if ($0 ~ "define.\x27" name "\x27") {
                    print stmt
                    replaced=1
                    while (replaced && !($0 ~ /\);/)) getline
                    next
                }
                print
            }
        ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    else
        awk -v stmt="$define_stmt" '
            NR==1 {print; print stmt; next}
            {print}
        ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    fi
done

# If IS_STATELESS only symlink wp-content/uploads
if [ "$IS_STATELESS" = "true" ]; then

    # Create directory uploads if it doesn't exist in /content
    if [ ! -d /content/wp-content/uploads ]; then
        mkdir -p /content/wp-content/uploads
        chown www-data:www-data /content/wp-content/uploads
        chmod -R 777 /content/wp-content/uploads
    fi

    ln -s /content/wp-content/uploads /var/www/html/wp-content/uploads
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
fi

# If IS_HTTPS is true, and IS_STATELESS is true it will create a .htaccess file to redirect HTTP to HTTPS
if [ "$IS_HTTPS" = "true" ] && [ "$IS_STATELESS" = "true" ]; then
    # if [ ! -f /var/www/html/.htaccess ]; then
    #     echo "RewriteEngine On" > /var/www/html/.htaccess
    #     echo "RewriteCond %{HTTPS} !=on" >> /var/www/html/.htaccess
    #     echo "RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R=301,L]" >> /var/www/html/.htaccess
    #     chown www-data:www-data /var/www/html/.htaccess
    # fi
    # Adding $_SERVER['HTTPS'] = 'on'; to wp-config.php after <?php
    if ! grep -q "\$_SERVER['HTTPS'] = 'on';" /var/www/html/wp-config.php; then
        awk "
        NR==1 {print; next}
        NR==2 {
            print \"if ( isset( \$_SERVER['HTTP_X_FORWARDED_PROTO'] ) && 'https' == \$_SERVER['HTTP_X_FORWARDED_PROTO'] ) {\";
            print \"    \$_SERVER['HTTPS'] = 'on';\";
            print \"}\";
            print;
            next
        }
        {print}
        " /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    fi
fi

if ! grep -q "# BEGIN WordPress" /var/www/html/.htaccess 2>/dev/null; then
    cat <<'EOF' >> /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
    chown www-data:www-data /var/www/html/.htaccess
    # w3-total-cache need write access to .htaccess
    chmod 777 /var/www/html/.htaccess
fi

# If has table prefix with variable CUSTOM_TABLE_PREFIX
if [ -n "$CUSTOM_TABLE_PREFIX" ]; then
    if ! grep -q "\$table_prefix = '$CUSTOM_TABLE_PREFIX';" /var/www/html/wp-config.php; then
        awk -v prefix="$CUSTOM_TABLE_PREFIX" '
        /table_prefix =/ {
            sub(/table_prefix = .*/, "table_prefix = '\''" prefix "'\'';");
            print;
            next
        }
        {print}
        ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
    fi
fi

# Set 777 permissions wp-content directory
# I have no idea how to set proper permissions for wp-content directory
# Some plugins doesn't wont running for example redis-object-cache
chmod -R 777 /var/www/html/wp-content
# This not secure but some plugins need write access to wp-config.php
# For example, w3-total-cache
chmod 777 /var/www/html/wp-config.php

exec "$@"