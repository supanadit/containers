FROM debian:bookworm

ARG WORDPRESS_VERSION="6.8.2"
ARG APACHE_VERSION="2.4.65"
ARG PHP_VERSION="8.3.23"
ARG APR_VERSION="1.7.6"
ARG APR_UTIL_VERSION="1.6.3"
ARG APACHE_EXPORTER_VERSION="1.0.10"

# Copy all setup scripts and resources
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Set working directory
WORKDIR /var/www/html

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

COPY addons.sh /opt/addons.sh
COPY addons/ /opt/addons/

COPY plugins /tmp/plugins
COPY themes /tmp/themes

RUN chmod +x /opt/addons.sh && \
    /opt/addons.sh && \
    rm /opt/addons.sh && \
    rm -rf /opt/addons

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
EXPOSE 80 9117