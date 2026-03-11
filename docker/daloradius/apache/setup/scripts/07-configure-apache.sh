#!/bin/bash
set -e

echo "=== Configuring Apache for daloRADIUS ==="

# Apache configuration paths
APACHE_CONF="/usr/local/apache2/conf/httpd.conf"
APACHE_MODULES="/usr/local/apache2/modules"

cd /usr/local/apache2

# Helper function to add a module only if not already present
add_module() {
    local module_name="$1"
    local module_path="$2"
    if ! grep -q "^LoadModule.*${module_name}" "$APACHE_CONF" 2>/dev/null; then
        echo "LoadModule ${module_name} ${module_path}" >> "$APACHE_CONF"
    fi
}

# Set ServerRoot
sed -i 's|^#*ServerRoot.*|ServerRoot "/usr/local/apache2"|' $APACHE_CONF

# Set ServerName
if ! grep -q "^ServerName" "$APACHE_CONF" 2>/dev/null; then
    echo "ServerName localhost" >> $APACHE_CONF
fi

# Configure Apache to listen on port 80 - remove existing Listen directives first
sed -i '/^Listen/d' $APACHE_CONF
echo "Listen 80" >> $APACHE_CONF

# Configure User and Group
sed -i 's/^User .*/User www-data/' $APACHE_CONF
sed -i 's/^Group .*/Group www-data/' $APACHE_CONF

# Configure Logging to Stdout/Stderr
sed -i 's|^ErrorLog .*|ErrorLog /proc/self/fd/2|' $APACHE_CONF
sed -i 's|^CustomLog .*|CustomLog /proc/self/fd/1 common|' $APACHE_CONF

# Find the actual PHP module name
PHP_MODULE=$(ls $APACHE_MODULES/libphp*.so 2>/dev/null | head -1)
if [ -n "$PHP_MODULE" ]; then
    PHP_MODULE_BASENAME=$(basename "$PHP_MODULE")
    # Add PHP module load directive if not already loaded
    if ! grep -q "LoadModule.*php" "$APACHE_CONF" 2>/dev/null; then
        echo "LoadModule php7_module modules/${PHP_MODULE_BASENAME}" >> $APACHE_CONF
    fi
fi

# Enable required modules (using helper to avoid duplicates)
add_module "mpm_prefork_module" "modules/mod_mpm_prefork.so"
add_module "rewrite_module" "modules/mod_rewrite.so"
add_module "dir_module" "modules/mod_dir.so"
add_module "mime_module" "modules/mod_mime.so"
add_module "log_config_module" "modules/mod_log_config.so"
add_module "env_module" "modules/mod_env.so"
add_module "setenvif_module" "modules/mod_setenvif.so"
add_module "authz_core_module" "modules/mod_authz_core.so"
add_module "authz_groupfile_module" "modules/mod_authz_groupfile.so"
add_module "authz_user_module" "modules/mod_authz_user.so"
add_module "auth_basic_module" "modules/mod_auth_basic.so"
add_module "socache_shmcb_module" "modules/mod_socache_shmcb.so"
add_module "ssl_module" "modules/mod_ssl.so"
add_module "unixd_module" "modules/mod_unixd.so"

# Configure MIME types - use Apache's built-in mime.types
sed -i 's|TypesConfig.*|TypesConfig conf/mime.types|' $APACHE_CONF

# Set DocumentRoot to daloRADIUS
sed -i 's|DocumentRoot.*|DocumentRoot "/var/www/html/daloradius"|' $APACHE_CONF

# Configure directory permissions
if ! grep -q '<Directory "/var/www/html">' "$APACHE_CONF" 2>/dev/null; then
cat >> $APACHE_CONF <<EOF
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
fi

# Add PHP index handler
sed -i 's|DirectoryIndex.*|DirectoryIndex index.php index.html|' $APACHE_CONF

# Add PHP handler (only if not already present)
if ! grep -q "SetHandler application/x-httpd-php" "$APACHE_CONF" 2>/dev/null; then
    cat >> $APACHE_CONF <<EOF

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
EOF
fi

# Configure PHP settings (only if not already present)
if ! grep -q "php_value upload_max_filesize" "$APACHE_CONF" 2>/dev/null; then
    cat >> $APACHE_CONF <<EOF
php_value upload_max_filesize 128M
php_value post_max_size 128M
php_value memory_limit 256M
php_value max_execution_time 300
php_value max_input_time 300
EOF
fi

# Set Mutex for stability
if ! grep -q "^Mutex posixsem" "$APACHE_CONF" 2>/dev/null; then
    echo "Mutex posixsem" >> $APACHE_CONF
fi

echo "=== Apache configured successfully ==="
