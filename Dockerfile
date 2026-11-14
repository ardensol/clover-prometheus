FROM grafana/grafana:10.4.19-security-01

# Copy Grafana provisioning files
COPY config/grafana/provisioning /etc/grafana/provisioning

# Expose Grafana port
EXPOSE 3000
