FROM grafana/grafana:13.3.1

# Copy Grafana provisioning files
COPY config/grafana/provisioning /etc/grafana/provisioning

# Expose Grafana port
EXPOSE 3000
