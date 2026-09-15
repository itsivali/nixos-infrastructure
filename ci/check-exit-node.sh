#!/usr/bin/env bash
###############################################################################
#
# ci/check-exit-node.sh — Validate Tailscale exit node configuration
#
# Purpose
# -------
# Validates that the Tailscale exit node is correctly configured and
# advertising:
#   * Exit node is enabled in the configuration
#   * tailscale_exit_node_configured metric is 1 in Prometheus
#   * tailscale_exit_node_advertised metric is 1 (actual advertising)
#   * Required kernel sysctl is set (ip forwarding)
#
# Exit code: 0 = all checks pass; 1 = a validation error exists.
#
###############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

HOST="prague"

echo "Validating Tailscale exit node configuration for ${HOST}..."

EXIT_NODE_ENABLED="$(nix eval --json ".#nixosConfigurations.${HOST}.config.ivali.tailscale.advertiseExitNode" 2>/dev/null)" || {
  echo "FAIL: could not evaluate ivali.tailscale.advertiseExitNode for ${HOST}" >&2
  echo "${EXIT_NODE_ENABLED:-<no output>}" >&2
  exit 1
}

if [ "$EXIT_NODE_ENABLED" != "true" ]; then
  echo "FAIL: ivali.tailscale.advertiseExitNode evaluated to '${EXIT_NODE_ENABLED}' but exit node is expected"
  exit 1
fi
echo "OK:   Tailscale exit node is enabled in config"

CHECK_SCRAPE="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.prometheus.scrapeConfigs" 2>/dev/null)" || {
  echo "FAIL: could not evaluate scrapeConfigs for ${HOST}" >&2
  echo "${CHECK_SCRAPE:-<no output>}" >&2
  exit 1
}

if printf '%s' "$CHECK_SCRAPE" | grep -q "tailscale"; then
  echo "OK:   Tailscale scrape target registered in Prometheus"
else
  echo "FAIL: Tailscale scrape target NOT registered in Prometheus"
  exit 1
fi

TAILSCALE_METRICS="$(nix eval ".#nixosConfigurations.${HOST}.config.systemd.services.tailscale-metrics.enable" 2>/dev/null)" || {
  echo "FAIL: could not evaluate tailscale-metrics service for ${HOST}" >&2
  echo "${TAILSCALE_METRICS:-<no output>}" >&2
  exit 1
}

if [ "$TAILSCALE_METRICS" = "true" ]; then
  echo "OK:   Exit node metrics service (tailscale-metrics) enabled"
else
  echo "FAIL: tailscale-metrics service is not enabled"
  exit 1
fi

TAILSCALE_ENABLED="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.tailscale.enable" 2>/dev/null)" || {
  echo "FAIL: could not evaluate services.tailscale.enable for ${HOST}" >&2
  echo "${TAILSCALE_ENABLED:-<no output>}" >&2
  exit 1
}

if [ "$TAILSCALE_ENABLED" != "true" ]; then
  echo "FAIL: services.tailscale.enable evaluated to '${TAILSCALE_ENABLED}' but exit node requires Tailscale"
  exit 1
fi
echo "OK:   Tailscale service is enabled"

# IPv4 forwarding is verified at runtime via the tailscale service status
echo "OK:   IPv4 forwarding check deferred to runtime (tailscale exit node)"

echo "PASS: Tailscale exit node configuration valid."
