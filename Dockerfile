FROM grafana/grafana:10.1.0

# Copy Grafana provisioning files
COPY config/grafana/provisioning /etc/grafana/provisioning

# Expose Grafana port
EXPOSE 3000
