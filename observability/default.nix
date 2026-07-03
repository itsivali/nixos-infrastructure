##############################################################################
#
# Observability Module
#
# Purpose
# -------
# Compose observability-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - options.nix    — Option namespace declarations
# - packages.nix   — Observability system packages
# - loki.nix       — Log aggregation
# - prometheus.nix — Metrics collection
# - grafana.nix    — Dashboard server
# - alloy.nix      — Journal-to-Loki forwarding
# - journald.nix   — Persistent journald logging
# - falco.nix      — Runtime security detection
# - otel.nix       — OpenTelemetry collector
# - alerting.nix   — Prometheus alerting rules
# - dashboards.nix — Grafana dashboard provisioning
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
