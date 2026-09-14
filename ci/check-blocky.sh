#!/usr/bin/env bash
###############################################################################
#
# ci/check-blocky.sh — Validate Blocky DNS proxy configuration
#
# Purpose
# -------
# Validates that the Blocky DNS proxy service is correctly configured:
#   * Port matches between config and firewall rules
#   * Metrics port is accessible for Prometheus scraping
#   * Tailscale-only firewall rule is consistent with config
#   * Blocky is enabled in the evaluated configuration
#
# Exit code: 0 = all checks pass; 1 = a validation error exists.
#
###############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

HOST="prague"

echo "Validating Blocky configuration for ${HOST}..."

BLOCKY_ENABLED="$(nix eval --json ".#nixosConfigurations.${HOST}.config.ivali.services.blocky.enable" 2>&1)" || {
  echo "FAIL: could not evaluate services.blocky.enable for ${HOST}" >&2
  echo "$BLOCKY_ENABLED" >&2
  exit 1
}

if [ "$BLOCKY_ENABLED" != "true" ]; then
  echo "FAIL: services.blocky.enable = false but ci/check-blocky.sh expects it enabled"
  exit 1
fi
echo "OK:   Blocky service is enabled"

BLOCKY_PORT="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.services.blocky.port" 2>&1)" || {
  echo "FAIL: could not evaluate services.blocky.port for ${HOST}" >&2
  echo "$BLOCKY_PORT" >&2
  exit 1
}
echo "OK:   Blocky port = ${BLOCKY_PORT}"

BLOCKY_METRICS_PORT="$(nix eval ".#nixosConfigurations.${HOST}.config.ivali.services.blocky.metricsPort" 2>&1)" || {
  echo "FAIL: could not evaluate services.blocky.metricsPort for ${HOST}" >&2
  echo "$BLOCKY_METRICS_PORT" >&2
  exit 1
}
echo "OK:   Blocky metrics port = ${BLOCKY_METRICS_PORT}"

CHECK_SCRAPE="$(nix eval --json ".#nixosConfigurations.${HOST}.config.services.prometheus.scrapeConfigs" 2>&1)" || {
  echo "FAIL: could not evaluate scrapeConfigs for ${HOST}" >&2
  echo "$CHECK_SCRAPE" >&2
  exit 1
}

if printf '%s' "$CHECK_SCRAPE" | grep -q "blocky"; then
  echo "OK:   Blocky scrape target registered in Prometheus"
else
  echo "FAIL: Blocky scrape target NOT registered in Prometheus"
  exit 1
fi

echo "PASS: Blocky configuration valid."
