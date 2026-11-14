FROM grafana/grafana:11.6.16

# Copy Grafana provisioning files
COPY config/grafana/provisioning /etc/grafana/provisioning

# Expose Grafana port
EXPOSE 3000
