FROM debian:bookworm

ARG FREERADIUS_VERSION="3.2.8"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /usr/local/freeradius

RUN mkdir -p /opt/container/entrypoint.d/scripts

COPY entrypoint.d/ /opt/container/entrypoint.d/

RUN chmod +x /opt/container/entrypoint.d/*.sh && \
    chmod +x /opt/container/entrypoint.d/scripts/**/*.sh || true

RUN mkdir -p /usr/local/freeradius/etc/raddb && \
    mkdir -p /usr/local/freeradius/log && \
    mkdir -p /usr/local/freeradius/run

ENTRYPOINT ["/opt/container/entrypoint.d/entrypoint.sh"]

VOLUME ["/usr/local/freeradius/etc/raddb", "/usr/local/freeradius/log"]

EXPOSE 1811/udp 1813/udp
