FROM grafana/grafana:12.4.15

# Copy Grafana provisioning files
COPY config/grafana/provisioning /etc/grafana/provisioning

# Expose Grafana port
EXPOSE 3000
