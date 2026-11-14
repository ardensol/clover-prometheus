# Clover Prometheus + Grafana Monitoring

Prometheus and Grafana monitoring stack for RestaurantOps (clover_order_poster) deployed via Kamal 2.

## Setup

1. **Update server IP** in `config/deploy.yml`:
   - Replace `YOUR_DIGITAL_OCEAN_IP` with your DigitalOcean droplet IP

2. **Create secrets file** at `.kamal/secrets` (gitignored):
   ```
   KAMAL_REGISTRY_PASSWORD=your_docker_hub_password
   GRAFANA_ADMIN_PASSWORD=your_grafana_admin_password
   DATA_SOURCE_NAME=postgresql://prometheus_exporter:PASSWORD@db-host:25060/defaultdb?sslmode=require
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
   REDIS_SIDEKIQ_URL=redis://...   # same value as the app's REDIS_SIDEKIQ_URL
   ```
   Alerts go to the Slack incoming webhook (`config/grafana/provisioning/alerting/notifications.yaml`).

   `SLACK_WEBHOOK_URL` is a Slack incoming webhook. Grafana provisions a Slack contact point from `config/grafana/provisioning/alerting/` and the default notification policy sends every alert there. Critical and warning are labeled in the message. The channel is the one the webhook was created for. Do not commit the webhook.

3. **Set up DNS** - Point `grafana.restaurantops.co` to your DigitalOcean IP

## Deploy

```bash
# First time setup
kamal setup

# Deploy updates
kamal deploy

# Redeploy accessories (Prometheus)
kamal accessory reboot prometheus

# First boot of a new accessory (kamal deploy does not start it)
kamal accessory boot sidekiq-exporter
```

## Upgrading Grafana and Prometheus

Upgrade one step per deploy, oldest first, and check each step before the next.
Each `clo-395` commit is one step: check it out, deploy it, then verify.

| Step | Grafana | Prometheus | Exporters | Commands |
|------|---------|------------|-----------|----------|
| 1 | 10.4.19-security-01 | v2.55.1 | | `kamal deploy`, `kamal accessory reboot prometheus` |
| 2 | 11.6.16 | | | `kamal deploy` |
| 3 | 12.4.15 | | | `kamal deploy` |
| 4 | 13.3.1 | v3.13.5 (LTS) | | `kamal deploy`, `kamal accessory reboot prometheus` |
| 5 | | | current | `kamal accessory reboot blackbox-exporter`, `... node-exporter`, `... postgres-exporter`, then `kamal deploy` (dashboard queries) |

Before step 1, back up Grafana's SQLite database on the host:

```bash
docker run --rm -v grafana_data:/d -v $PWD:/b alpine tar czf /b/grafana_data.tgz -C /d .
```

Grafana migrates its database on start and cannot be downgraded. To roll back
a Grafana step, stop the service, restore `grafana_data.tgz` into the volume,
and deploy the previous commit.

Prometheus 2.55 reads and writes the TSDB format 3.x uses, so rolling back from
3.x to 2.55 keeps the data. Do not go back to 2.47 after 2.55 or 3.x has run.

After each step:

```bash
curl -s https://grafana.restaurantops.co/api/health
# All alert rules report health "ok"
curl -s -u admin:$GRAFANA_ADMIN_PASSWORD https://grafana.restaurantops.co/api/prometheus/grafana/api/v1/rules
# All targets up, and the oldest data is still about 30 days old (9090 is firewalled from outside)
ssh root@161.35.237.161 curl -s localhost:9090/api/v1/targets
ssh root@161.35.237.161 "curl -s localhost:9090/api/v1/query --data-urlencode 'query=min_over_time(timestamp(up{job=\"prometheus\"})[30d:1h])'"
```

Then open both dashboards and check that the panels load.

## Architecture

- **Grafana**: Main service with SSL via Kamal proxy on `grafana.restaurantops.co`
- **Alerts**: Rules in `config/grafana/provisioning/alerting/alerts.yaml`. Contact point and notification policy in the same directory route them to Slack.
- **Prometheus**: Accessory container (internal only, port 9090)
- **Blackbox exporter**: Accessory container (no published port) that probes the DigitalOcean load balancers (TCP connect) and the `/up` health endpoints (HTTPS). Shown on the "Load Balancers & Uptime" dashboard, with alerts in the Load Balancers folder
- **Sidekiq exporter**: Accessory container (`strech/sidekiq-prometheus-exporter`, no published port) that reads queue size and latency, processed/failed totals, and the retry, dead and scheduled sets from the app's Sidekiq Redis. The values are cluster-wide, so the job servers publish no metrics port. Redis must accept connections from this droplet. Shown in the Sidekiq row of the Rails dashboard, with alerts in the Sidekiq folder. If it can't reach Redis, its scrape fails and InstanceDown fires

## Scrape Targets

Production servers being monitored:
- Web: 64.23.192.251, 64.23.182.234 (Rails `/metrics` and node exporter)
- Job: 143.110.154.221, 64.23.140.194 (node exporter; Sidekiq metrics come from the sidekiq-exporter accessory, which reads Redis)
- Monitoring: this droplet, via the node-exporter accessory
- Load balancers: 64.225.88.153 (orders.restaurantops.co), 143.244.211.166 (orders.menugram.app), 24.199.69.51 (blackbox TCP probes)

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
- Sidekiq row: queue latency and size by queue, jobs processed/failed, retry/dead/scheduled sets, failed jobs by class, busy workers
