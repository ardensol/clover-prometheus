#!/usr/bin/env bash
# Unit-tests Grafana alert rules with promtool.
# Grafana rules aren't Prometheus rule files, so this copies each tested rule's
# query (refId A) into a Prometheus alert that fires when the query is > 0.5,
# the threshold every rule in alerts.yaml uses, then runs `promtool test rules`.
# Needs promtool (same version as deploy.yml) and python3 with PyYAML.
set -euo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - "$tmp/rules.yml" <<'PY'
import sys, yaml
alerts = yaml.safe_load(open("../config/grafana/provisioning/alerting/alerts.yaml"))
rules = []
for group in alerts["groups"]:
    for rule in group["rules"]:
        if rule["uid"] in {"checkout-payments-failing"}:
            expr = next(d for d in rule["data"] if d["refId"] == "A")["model"]["expr"]
            rules.append({"alert": rule["title"], "expr": "(" + expr.strip() + ") > 0.5"})
yaml.safe_dump({"groups": [{"name": "grafana", "rules": rules}]}, open(sys.argv[1], "w"), sort_keys=False, width=1000)
PY

for t in *_test.yml; do cp "$t" "$tmp/"; done
cd "$tmp"
promtool check rules rules.yml
promtool test rules *_test.yml
