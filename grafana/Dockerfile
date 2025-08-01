FROM debian:bookworm

ARG GRAFANA_VERSION="12.1.0"
ARG GRAFANA_EDITION="oss"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/grafana

# Copy entrypoint script
COPY entrypoint.sh /opt/grafana/entrypoint.sh
RUN chmod +x /opt/grafana/entrypoint.sh

ENTRYPOINT ["/opt/grafana/entrypoint.sh"]

CMD ["/usr/share/grafana/bin/grafana", "server", \
     "--homepath=/usr/share/grafana", \
     "--config=/etc/grafana/grafana.ini", \
     "cfg:default.paths.data=/var/lib/grafana", \
     "cfg:default.paths.logs=/var/log/grafana", \
     "cfg:default.paths.plugins=/var/lib/grafana/plugins", \
     "cfg:default.paths.provisioning=/etc/grafana/provisioning"]

EXPOSE 3000