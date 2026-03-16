# Clover Prometheus + Grafana Monitoring

Prometheus and Grafana monitoring stack for RestaurantOps (clover_order_poster) deployed via Kamal 2.

## Setup

1. **Update server IP** in `config/deploy.yml`:
   - Replace `YOUR_DIGITAL_OCEAN_IP` with your DigitalOcean droplet IP

2. **Create secrets file** at `.kamal/secrets`:
   ```
   KAMAL_REGISTRY_PASSWORD=your_docker_hub_password
   GRAFANA_ADMIN_PASSWORD=your_grafana_admin_password
   ```

3. **Set up DNS** - Point `grafana.restaurantops.co` to your DigitalOcean IP

## Deploy

```bash
# First time setup
kamal setup

# Deploy updates
kamal deploy

# Redeploy accessories (Prometheus)
kamal accessory reboot prometheus
```

## Architecture

- **Grafana**: Main service with SSL via Kamal proxy on `grafana.restaurantops.co`
- **Prometheus**: Accessory container (internal only, port 9090)

## Scrape Targets

Production servers being monitored:
- Web: 64.23.192.251, 64.23.182.234
- Job: 143.110.154.221, 64.23.140.194
- Job-Critical: 143.198.149.49

## Rails App Requirements

Your Rails app needs the `prometheus_exporter` gem exposing metrics on `/metrics`.

Add to Gemfile:
```ruby
gem 'prometheus_exporter'
```

Add initializer `config/initializers/prometheus.rb`:
```ruby
require 'prometheus_exporter/middleware'

Rails.application.middleware.unshift PrometheusExporter::Middleware
```

Run the collector:
```bash
bundle exec prometheus_exporter
```

## Dashboards

Pre-configured dashboard includes:
- Request rate by instance
- Request latency percentiles (p50, p95, p99)
- Requests by status code
- Error rate (5xx)
- Puma thread utilization
- DB connection pool utilization
- Healthy instances count
- Slowest endpoints (p95)
