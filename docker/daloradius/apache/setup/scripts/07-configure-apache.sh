#!/bin/bash
set -e

echo "=== Configuring Apache for daloRADIUS ==="

# Apache configuration paths
APACHE_CONF="/usr/local/apache2/conf/httpd.conf"
APACHE_MODULES="/usr/local/apache2/modules"

cd /usr/local/apache2

# Set ServerRoot
sed -i 's|^#*ServerRoot.*|ServerRoot "/usr/local/apache2"|' $APACHE_CONF

# Configure Apache to listen on port 80
sed -i 's|^#*Listen.*|Listen 80|' $APACHE_CONF

# Find the actual PHP module name
PHP_MODULE=$(ls $APACHE_MODULES/libphp*.so 2>/dev/null | head -1)
if [ -n "$PHP_MODULE" ]; then
    PHP_MODULE_BASENAME=$(basename "$PHP_MODULE")
    # Add PHP module load directive
    echo "LoadModule php7_module modules/${PHP_MODULE_BASENAME}" >> $APACHE_CONF
fi

# Enable required modules
echo "LoadModule mpm_prefork_module modules/mod_mpm_prefork.so" >> $APACHE_CONF
echo "LoadModule rewrite_module modules/mod_rewrite.so" >> $APACHE_CONF
echo "LoadModule dir_module modules/mod_dir.so" >> $APACHE_CONF
echo "LoadModule mime_module modules/mod_mime.so" >> $APACHE_CONF
echo "LoadModule log_config_module modules/mod_log_config.so" >> $APACHE_CONF
echo "LoadModule env_module modules/mod_env.so" >> $APACHE_CONF
echo "LoadModule setenvif_module modules/mod_setenvif.so" >> $APACHE_CONF
echo "LoadModule authz_core_module modules/mod_authz_core.so" >> $APACHE_CONF
echo "LoadModule authz_groupfile_module modules/mod_authz_groupfile.so" >> $APACHE_CONF
echo "LoadModule authz_user_module modules/mod_authz_user.so" >> $APACHE_CONF
echo "LoadModule auth_basic_module modules/mod_auth_basic.so" >> $APACHE_CONF
echo "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" >> $APACHE_CONF
echo "LoadModule ssl_module modules/mod_ssl.so" >> $APACHE_CONF

# Configure MIME types
sed -i 's|TypesConfig.*|TypesConfig /etc/mime.types|' $APACHE_CONF

# Set DocumentRoot to daloRADIUS
sed -i 's|DocumentRoot.*|DocumentRoot "/var/www/html/daloradius"|' $APACHE_CONF

# Configure directory permissions
sed -i 's|<Directory ".*">|<Directory "/var/www/html">|' $APACHE_CONF

# Add PHP index handler
sed -i 's|DirectoryIndex.*|DirectoryIndex index.php index.html|' $APACHE_CONF

# Add PHP handler
cat >> $APACHE_CONF <<EOF

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
EOF

# Configure PHP settings
cat >> $APACHE_CONF <<EOF
php_value upload_max_filesize 128M
php_value post_max_size 128M
php_value memory_limit 256M
php_value max_execution_time 300
php_value max_input_time 300
EOF

# Set Mutex for stability
echo "Mutex posixsem" >> $APACHE_CONF

echo "=== Apache configured successfully ==="
