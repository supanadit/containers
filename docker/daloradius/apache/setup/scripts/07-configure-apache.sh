#!/bin/bash
set -e

echo "=== Configuring Apache for daloRADIUS ==="

# Configure Apache
cd /usr/local/apache2

# Set ServerRoot
sed -i 's|#ServerRoot "ServerRoot"|ServerRoot "/usr/local/apache2"|' etc/httpd.conf

# Configure Apache to listen on port 80
sed -i 's|#Listen 80|Listen 80|' etc/httpd.conf

# Enable PHP module
sed -i 's|#LoadModule php_module|LoadModule php_module|' modules/libphp*.so
sed -i 's|#LoadModule mpm_prefork_module|LoadModule mpm_prefork_module|' modules/mod_mpm_prefork.so || true

# Enable required modules
echo "LoadModule rewrite_module modules/mod_rewrite.so" >> etc/httpd.conf
echo "LoadModule dir_module modules/mod_dir.so" >> etc/httpd.conf
echo "LoadModule mime_module modules/mod_mime.so" >> etc/httpd.conf
echo "LoadModule log_config_module modules/mod_log_config.so" >> etc/httpd.conf
echo "LoadModule env_module modules/mod_env.so" >> etc/httpd.conf
echo "LoadModule setenvif_module modules/mod_setenvif.so" >> etc/httpd.conf
echo "LoadModule authz_core_module modules/mod_authz_core.so" >> etc/httpd.conf
echo "LoadModule authz_groupfile_module modules/mod_authz_groupfile.so" >> etc/httpd.conf
echo "LoadModule authz_user_module modules/mod_authz_user.so" >> etc/httpd.conf
echo "LoadModule auth_basic_module modules/mod_auth_basic.so" >> etc/httpd.conf
echo "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" >> etc/httpd.conf
echo "LoadModule ssl_module modules/mod_ssl.so" >> etc/httpd.conf

# Configure MIME types
sed -i 's|TypesConfig etc/mime.types|TypesConfig /etc/mime.types|' etc/httpd.conf

# Set DocumentRoot to daloRADIUS
sed -i 's|DocumentRoot "/usr/local/apache2/htdocs"|DocumentRoot "/var/www/html/daloradius"|' etc/httpd.conf

# Configure directory permissions
sed -i 's|<Directory "htdocs">|<Directory "/var/www/html">|' etc/httpd.conf

# Add PHP index handler
sed -i 's|DirectoryIndex index.html|DirectoryIndex index.php index.html|' etc/httpd.conf

# Add PHP handler
echo "" >> etc/httpd.conf
echo "<FilesMatch \\.php$>" >> etc/httpd.conf
echo "    SetHandler application/x-httpd-php" >> etc/httpd.conf
echo "</FilesMatch>" >> etc/httpd.conf

# Configure PHP settings
echo "" >> etc/httpd.conf
echo "php_value upload_max_filesize 128M" >> etc/httpd.conf
echo "php_value post_max_size 128M" >> etc/httpd.conf
echo "php_value memory_limit 256M" >> etc/httpd.conf
echo "php_value max_execution_time 300" >> etc/httpd.conf
echo "php_value max_input_time 300" >> etc/httpd.conf

# Set Mutex for stability
echo "Mutex posixsem" >> etc/httpd.conf

# Fix php module loading order
sed -i 's|LoadModule mpm_prefork_module|LoadModule php_module modules/libphp*.so\nLoadModule mpm_prefork_module|' etc/httpd.conf

echo "=== Apache configured successfully ==="
