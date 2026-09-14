#!/usr/bin/env bash
###############################################################################
#
# ci/check-scrape-targets.sh — Validate Prometheus scrape targets
#
# Purpose
# -------
# Every declared Prometheus scrape target must correspond to a service that is
# actually enabled in the prague configuration. This prevents silent data gaps
# where prometheus.nix scraps a port but the owning service was never enabled
# (or was renamed) in the module configuration.
#
# The check evaluates the prague NixOS configuration's scrape configs and
# compares each job's target host:port against the list of ports that the
# enabled services are known to listen on.
#
# Exit code: 0 = all targets match an enabled service; 1 = a mismatch exists.
#
###############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

HOST="prague"

# Services known to expose Prometheus metrics on loopback, indexed by port.
# Each port maps to the service setting that must be enabled for the port to
# be valid. When a new metrics service is added, register it here AND in
# observability/prometheus.nix.
declare -A SERVICE_PORTS=(
  [9090]="services.prometheus"        # Prometheus itself
  [9093]="ivali.observability.alertmanager" # Alertmanager
  [3000]="ivali.observability"        # Grafana (enabled with observability)
  [3100]="ivali.observability.loki"   # Loki
  [12345]="ivali.observability.alloy" # Grafana Alloy
  [4000]="services.blocky"            # Blocky DNS metrics
  [8888]="ivali.observability.otel"      # OTel collector metrics
  [9120]="ivali.security.scanning"      # Security scanner metrics
  [9100]="services.prometheus.exporters.node" # node_exporter
  [9101]="ivali.observability.exporters"      # nixos-exporter
  [9121]="services.tailscale"         # tailscale metrics
  [9710]="ivali.observability.healthEndpoint" # health endpoint
  [8080]="ivali.services.webUI"       # ivali-api
)

echo "Evaluating ${HOST} Prometheus scrape targets..."

eval_out="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.prometheus.scrapeConfigs" 2>&1)" || {
  echo "FAIL: could not evaluate scrapeConfigs for ${HOST}:" >&2
  echo "$eval_out" >&2
  exit 1
}

# Extract unique "host:port" targets from the evaluated JSON.
targets="$(printf '%s' "$eval_out" |
  nix run nixpkgs#jq -- -r '.[].static_configs[].targets[]' 2>/dev/null | sort -u)"

if [ -z "$targets" ]; then
  targets="$(printf '%s' "$eval_out" | python3 -c '
import json, sys
data = json.load(sys.stdin)
seen = set()
for job in data:
    for sc in job.get("static_configs", []):
        for t in sc.get("targets", []):
            seen.add(t)
for t in sorted(seen):
    print(t)
')"
fi

echo "Declared scrape targets:"
printf '%s\n' "$targets"
echo

# Evaluate which option values are true in the configuration.
prometheus="$(nix eval ".#nixosConfigurations.${HOST}.config.services.prometheus.enable" 2>&1)" || { echo "FAIL"; exit 1; }
alertmanager="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.alertmanager.enable" 2>&1)" || { echo "FAIL"; exit 1; }
observability="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.enable" 2>&1)" || { echo "FAIL"; exit 1; }
loki="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.loki.enable" 2>&1)" || { echo "FAIL"; exit 1; }
alloy="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.alloy.enable" 2>&1)" || { echo "FAIL"; exit 1; }
blocky="$(nix eval ".#nixosConfigurations.${HOST}.config.services.blocky.enable" 2>&1)" || { echo "FAIL"; exit 1; }
nodeExporter="$(nix eval ".#nixosConfigurations.${HOST}.config.services.prometheus.exporters.node.enable" 2>&1)" || { echo "FAIL"; exit 1; }
exporters="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.exporters.enable" 2>&1)" || { echo "FAIL"; exit 1; }
tailscale="$(nix eval ".#nixosConfigurations.${HOST}.config.services.tailscale.enable" 2>&1)" || { echo "FAIL"; exit 1; }
health="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.healthEndpoint.enable" 2>&1)" || { echo "FAIL"; exit 1; }
webUI="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.services.webUI.enable" 2>&1)" || { echo "FAIL"; exit 1; }
otel="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.observability.otel.enable" 2>&1)" || { echo "FAIL"; exit 1; }
scanning="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.security.scanning.enable" 2>&1)" || { echo "FAIL"; exit 1; }

# Build a list of enabled service names.
enabled_services=""
for svc in prometheus alertmanager observability loki alloy blocky nodeExporter exporters tailscale health webUI otel scanning; do
  val="${!svc}"
  if [ "$val" = "true" ]; then
    enabled_services="${enabled_services}${svc} "
  fi
done



port_to_service() {
  # Map service name from SERVICE_PORTS (strip lib.optional variant via name)
  local port="$1"
  echo "${SERVICE_PORTS[$port]:-}"
}

failures=0
# For each declared target, find its port and verify the owning service is
# enabled in the evaluated config.
while IFS= read -r target; do
  [ -n "$target" ] || continue
  port="${target##*:}"
  service="${SERVICE_PORTS[$port]:-unknown}"
  if [ "$service" = "unknown" ]; then
    echo "FAIL: scrape target ${target} has no registered owning service in ci/check-scrape-targets.sh"
    failures=$((failures + 1))
    continue
  fi
  case "$service" in
    services.prometheus)     enabled="prometheus";;
    ivali.observability.alertmanager) enabled="alertmanager";;
    ivali.observability)     enabled="observability";;
    ivali.observability.loki) enabled="loki";;
    ivali.observability.alloy) enabled="alloy";;
    services.blocky)         enabled="blocky";;
    services.prometheus.exporters.node) enabled="nodeExporter";;
    ivali.observability.exporters) enabled="exporters";;
    services.tailscale)      enabled="tailscale";;
    ivali.observability.healthEndpoint) enabled="health";;
    ivali.services.webUI)    enabled="webUI";;
    ivali.observability.otel) enabled="otel";;
    ivali.security.scanning) enabled="scanning";;
    *) enabled="";;
  esac
  if [ -z "$enabled" ]; then
    echo "FAIL: unknown service mapping for port ${port}"
    failures=$((failures + 1))
  elif ! printf '%s\n' "$enabled_services" | grep -qx "$enabled"; then
    echo "FAIL: scrape target ${target} (${service}) is declared but ${service} is NOT enabled on ${HOST}"
    failures=$((failures + 1))
  else
    echo "OK:   scrape target ${target} matches enabled service ${service}"
  fi
done <<< "$targets"

echo
if [ "$failures" -gt 0 ]; then
  echo "FAIL: ${failures} scrape target(s) have no corresponding enabled service."
  exit 1
fi

echo "PASS: all scrape targets correspond to enabled services."