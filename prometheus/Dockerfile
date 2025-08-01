FROM debian:bookworm

ARG PROMETHEUS_VERSION="3.5.0"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/prometheus

# Copy entrypoint script
COPY entrypoint.sh /opt/prometheus/entrypoint.sh
RUN chmod +x /opt/prometheus/entrypoint.sh

ENTRYPOINT ["/opt/prometheus/entrypoint.sh"]

CMD ["prometheus", "--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/opt/prometheus/data", "--web.listen-address=:9090"]
VOLUME ["/prometheus"]
EXPOSE 9090