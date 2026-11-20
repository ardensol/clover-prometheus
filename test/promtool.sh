#!/usr/bin/env bash
# Unit-tests Grafana alert rules with promtool.
# Grafana rules aren't Prometheus rule files, so this copies each tested rule's
# query (refId A) into a Prometheus alert that fires when the query passes the
# rule's threshold (refId C, gt or lt), then runs `promtool test rules`.
# The rule's `for` is not copied, so tests check the query at eval_time.
# Needs promtool (same version as deploy.yml) and python3 with PyYAML.
set -euo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - "$tmp/rules.yml" <<'PY'
import sys, yaml
TESTED = {
    "high-error-rate", "checkout-server-error", "checkout-payments-failing",
    "monitoring-down", "monitoring-target-down",
    "monitoring-prometheus-restarted", "monitoring-prometheus-memory-high",
}
alerts = yaml.safe_load(open("../config/grafana/provisioning/alerting/alerts.yaml"))
rules = []
for group in alerts["groups"]:
    for rule in group["rules"]:
        if rule["uid"] in TESTED:
            data = {d["refId"]: d["model"] for d in rule["data"]}
            evaluator = data["C"]["conditions"][0]["evaluator"]
            op = {"gt": ">", "lt": "<"}[evaluator["type"]]
            rules.append({"alert": rule["title"], "expr": f"({data['A']['expr'].strip()}) {op} {evaluator['params'][0]}"})
yaml.safe_dump({"groups": [{"name": "grafana", "rules": rules}]}, open(sys.argv[1], "w"), sort_keys=False, width=1000)
PY

for t in *_test.yml; do cp "$t" "$tmp/"; done
cd "$tmp"
promtool check rules rules.yml
promtool test rules *_test.yml
