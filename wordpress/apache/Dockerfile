FROM debian:bookworm

RUN apt-get update && apt-get install -y wget unzip build-essential perl libexpat1-dev libpcre3-dev libssl-dev pkg-config libxml2-dev sqlite3 libsqlite3-dev libcurl4-openssl-dev libonig-dev zlib1g-dev curl git autoconf

ARG WORDPRESS_VERSION="6.8.2"
ARG APACHE_VERSION="2.4.64"
ARG PHP_VERSION="8.3.23"
ARG APR_VERSION="1.7.6"
ARG APR_UTIL_VERSION="1.6.3"

# Download and extract Apache from Source Code
RUN wget https://downloads.apache.org/httpd/httpd-${APACHE_VERSION}.tar.gz && \
    tar -xzf httpd-${APACHE_VERSION}.tar.gz && \
    rm httpd-${APACHE_VERSION}.tar.gz

# Download and extract APR and APR-util
RUN wget https://downloads.apache.org/apr/apr-${APR_VERSION}.tar.gz && \
    tar -xzf apr-${APR_VERSION}.tar.gz && \
    rm apr-${APR_VERSION}.tar.gz && \
    wget https://downloads.apache.org/apr/apr-util-${APR_UTIL_VERSION}.tar.gz && \
    tar -xzf apr-util-${APR_UTIL_VERSION}.tar.gz && \
    rm apr-util-${APR_UTIL_VERSION}.tar.gz

# Install APR and APR-util
RUN cd apr-${APR_VERSION} && \
    ./configure && make && make install && \
    cd ../apr-util-${APR_UTIL_VERSION} && \
    ./configure --with-apr=/usr/local/apr && make && make install && \
    make clean

# Install Apache
RUN cd httpd-${APACHE_VERSION} && \
    ./configure --with-apr=/usr/local/apr --with-apr-util=/usr/local/apr/bin/apu-1-config --enable-so --enable-ssl --with-mpm=event && \
    make && make install && \
    make clean

WORKDIR /tmp/downloads/php

# Download and extract PHP
RUN wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz && \
    tar -xzf php-${PHP_VERSION}.tar.gz && \
    rm php-${PHP_VERSION}.tar.gz

# Install and compile PHP
RUN cd php-${PHP_VERSION} && \
    ./configure --with-apxs2=/usr/local/apache2/bin/apxs --enable-mbstring --with-curl --with-openssl --with-pdo-mysql --with-mysqli && \
    make -j$(nproc) && make install && \
    make clean

RUN cp /tmp/downloads/php/php-${PHP_VERSION}/php.ini-production /usr/local/lib/php.ini && \
    sed -i 's/;date.timezone =/date.timezone = UTC/' /usr/local/lib/php.ini

# START PHP Extensions

# Install PHP EXIF extension
RUN cd /tmp/downloads/php/php-${PHP_VERSION}/ext/exif && \
    /usr/local/bin/phpize && \
    ./configure --with-php-config=/usr/local/bin/php-config && \
    make && make install && \
    echo "extension=exif.so" >> /usr/local/lib/php.ini

# Install and enable PHP OPCache extension
RUN cd /tmp/downloads/php/php-${PHP_VERSION}/ext/opcache && \
    /usr/local/bin/phpize && \
    ./configure --with-php-config=/usr/local/bin/php-config && \
    make && make install && \
    echo "zend_extension=opcache.so" >> /usr/local/lib/php.ini

# Download and install PHP Redis extension
RUN git clone https://github.com/phpredis/phpredis.git /tmp/phpredis && \
    cd /tmp/phpredis && \
    phpize && \
    ./configure --with-php-config=/usr/local/bin/php-config && \
    make && make install && \
    echo "extension=redis.so" >> /usr/local/lib/php.ini && \
    rm -rf /tmp/phpredis

# END PHP Extensions

WORKDIR /var/www/html
# Download and extract WordPress
RUN wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz && \
    tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz && \
    rm wordpress-${WORDPRESS_VERSION}.tar.gz && \
    mv wordpress/* . && \
    rm -rf wordpress

# Change the default Apache document root
RUN sed -i 's|DocumentRoot "/usr/local/apache2/htdocs"|DocumentRoot "/var/www/html"|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|<Directory "/usr/local/apache2/htdocs">|<Directory "/var/www/html">|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|AllowOverride None|AllowOverride All|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|Require all denied|Require all granted|' /usr/local/apache2/conf/httpd.conf

# Set index.php as the default index file
RUN sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' /usr/local/apache2/conf/httpd.conf
# Enable PHP in Apache
RUN echo "LoadModule php_module modules/libphp.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddType application/x-httpd-php .php" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddType application/x-httpd-php .html" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddType application/x-httpd-php .htm" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddType application/x-httpd-php .phtml" >> /usr/local/apache2/conf/httpd.conf

# Sed and uncomment the following lines in httpd.conf to enable PHP
RUN sed -i 's/#LoadModule rewrite_module modules\/mod_rewrite.so/LoadModule rewrite_module modules\/mod_rewrite.so/' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/#LoadModule headers_module modules\/mod_headers.so/LoadModule headers_module modules\/mod_headers.so/' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/#LoadModule env_module modules\/mod_env.so/LoadModule env_module modules\/mod_env.so/' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/#LoadModule mime_module modules\/mod_mime.so/LoadModule mime_module modules\/mod_mime.so/' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/#LoadModule dir_module modules\/mod_dir.so/LoadModule dir_module modules\/mod_dir.so/' /usr/local/apache2/conf/httpd.conf

# Cleanup
RUN rm -rf /tmp/downloads/php/php-${PHP_VERSION} && \
    rm -rf /tmp/downloads/php && \
    rm -rf /tmp/downloads/apr-${APR_VERSION} && \
    rm -rf /tmp/downloads/apr-util-${APR_UTIL_VERSION} && \
    rm -rf /tmp/downloads/httpd-${APACHE_VERSION} && \
    rm -rf /tmp/downloads/php-${PHP_VERSION} && \
    rm -rf /tmp/downloads

# Clean up apt cache
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Clean up unecessary apt packages
RUN apt-get autoremove -y && \
    apt-get autoclean -y

# Setup Plugins
COPY scripts /opt/scripts
RUN chmod +x /opt/scripts/*.sh

COPY plugins /tmp/plugins
COPY themes /tmp/themes

RUN /opt/scripts/plugin-install.sh /tmp/plugins
RUN /opt/scripts/theme-install.sh /tmp/themes

# Set permissions for WordPress
RUN chown -R www-data:www-data /var/www/html

# Clean up downloaded plugins and themes
RUN rm -rf /tmp/plugins /tmp/themes

# Run Apache in the foreground
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
EXPOSE 80