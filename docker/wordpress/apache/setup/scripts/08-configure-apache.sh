#!/bin/bash
set -e

echo "=== Configuring Apache ==="

# Ensure www-data user and group exist
if ! id -u www-data >/dev/null 2>&1; then
    echo "Creating www-data user and group"
    groupadd -r www-data
    useradd -r -g www-data www-data
fi

# Change the default Apache document root
sed -i 's|DocumentRoot "/usr/local/apache2/htdocs"|DocumentRoot "/var/www/html"|' /usr/local/apache2/conf/httpd.conf
sed -i 's|<Directory "/usr/local/apache2/htdocs">|<Directory "/var/www/html">|' /usr/local/apache2/conf/httpd.conf
sed -i 's|AllowOverride None|AllowOverride All|' /usr/local/apache2/conf/httpd.conf
sed -i 's|Require all denied|Require all granted|' /usr/local/apache2/conf/httpd.conf

# Set Apache to run as www-data user and group
sed -i 's/User daemon/User www-data/' /usr/local/apache2/conf/httpd.conf
sed -i 's/Group daemon/Group www-data/' /usr/local/apache2/conf/httpd.conf

# Set index.php as the default index file
sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' /usr/local/apache2/conf/httpd.conf

# Enable PHP in Apache
echo "LoadModule php_module modules/libphp.so" >> /usr/local/apache2/conf/httpd.conf
echo "AddType application/x-httpd-php .php" >> /usr/local/apache2/conf/httpd.conf
echo "AddType application/x-httpd-php .html" >> /usr/local/apache2/conf/httpd.conf
echo "AddType application/x-httpd-php .htm" >> /usr/local/apache2/conf/httpd.conf
echo "AddType application/x-httpd-php .phtml" >> /usr/local/apache2/conf/httpd.conf

# Enable necessary Apache modules
sed -i 's/#LoadModule rewrite_module modules\/mod_rewrite.so/LoadModule rewrite_module modules\/mod_rewrite.so/' /usr/local/apache2/conf/httpd.conf
sed -i 's/#LoadModule headers_module modules\/mod_headers.so/LoadModule headers_module modules\/mod_headers.so/' /usr/local/apache2/conf/httpd.conf
sed -i 's/#LoadModule env_module modules\/mod_env.so/LoadModule env_module modules\/mod_env.so/' /usr/local/apache2/conf/httpd.conf
sed -i 's/#LoadModule mime_module modules\/mod_mime.so/LoadModule mime_module modules\/mod_mime.so/' /usr/local/apache2/conf/httpd.conf
sed -i 's/#LoadModule dir_module modules\/mod_dir.so/LoadModule dir_module modules\/mod_dir.so/' /usr/local/apache2/conf/httpd.conf

echo "=== Apache configured successfully ==="
