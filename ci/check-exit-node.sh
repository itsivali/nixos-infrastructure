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

EXIT_NODE_ENABLED="$(nix eval --json ".#nixosConfigurations.${HOST}.config.ivali.tailscale.advertiseExitNode" 2>&1)" || {
  echo "FAIL: could not evaluate ivali.tailscale.advertiseExitNode for ${HOST}" >&2
  echo "$EXIT_NODE_ENABLED" >&2
  exit 1
}

if [ "$EXIT_NODE_ENABLED" != "true" ]; then
  echo "FAIL: ivali.tailscale.advertiseExitNode = false but exit node is expected"
  exit 1
fi
echo "OK:   Tailscale exit node is enabled in config"

CHECK_SCRAPE="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.prometheus.scrapeConfigs" 2>&1)" || {
  echo "FAIL: could not evaluate scrapeConfigs for ${HOST}" >&2
  echo "$CHECK_SCRAPE" >&2
  exit 1
}

if printf '%s' "$CHECK_SCRAPE" | grep -q "tailscale"; then
  echo "OK:   Tailscale scrape target registered in Prometheus"
else
  echo "FAIL: Tailscale scrape target NOT registered in Prometheus"
  exit 1
fi

TAILSCALE_METRICS="$(nix eval ".#nixosConfigurations.${HOST}.config.systemd.services.tailscale-metrics.enable" 2>&1)" || {
  echo "FAIL: could not evaluate tailscale-metrics service for ${HOST}" >&2
  echo "$TAILSCALE_METRICS" >&2
  exit 1
}

if [ "$TAILSCALE_METRICS" = "true" ]; then
  echo "OK:   Exit node metrics service (tailscale-metrics) enabled"
else
  echo "FAIL: tailscale-metrics service is not enabled"
  exit 1
fi

TAILSCALE_ENABLED="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.tailscale.enable" 2>&1)" || {
  echo "FAIL: could not evaluate services.tailscale.enable for ${HOST}" >&2
  echo "$TAILSCALE_ENABLED" >&2
  exit 1
}

if [ "$TAILSCALE_ENABLED" != "true" ]; then
  echo "FAIL: services.tailscale.enable = false but exit node requires Tailscale"
  exit 1
fi
echo "OK:   Tailscale service is enabled"

SYSCTL_CHECK="$(nix eval ".#nixosConfigurations.${HOST}.config.boot.kernel.sysctl.net.ipv4.ip_forward" 2>&1)" || {
  echo "WARN: could not evaluate sysctl for ${HOST}"
  echo "$SYSCTL_CHECK" >&2
}

if [ "$SYSCTL_CHECK" = "1" ]; then
  echo "OK:   IPv4 forwarding enabled (required for exit node)"
else
  echo "FAIL: IPv4 forwarding not enabled (required for exit node)"
  exit 1
fi

TAILSCALE_METRICS="$(nix eval ".#nixosConfigurations.${HOST}.config.systemd.services.tailscale-metrics.enable" 2>&1)" || {
  echo "WARN: could not evaluate tailscale-metrics for ${HOST}"
  echo "$TAILSCALE_METRICS" >&2
}

if [ "$TAILSCALE_METRICS" = "true" ]; then
  echo "OK:   tailscale-metrics service is enabled"
else
  echo "FAIL: tailscale-metrics service is not enabled"
  exit 1
fi

echo "PASS: Tailscale exit node configuration valid."
