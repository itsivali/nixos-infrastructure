##############################################################################
#
# Observability Packages
#
# Purpose
# -------
# Install observability-related system packages.
#
# Ownership
# ---------
# environment.systemPackages for observability tooling
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
in
{
  environment.systemPackages = with pkgs;
    [
      syft
      trivy
    ]
    ++ lib.optionals cfg.loki.enable [ grafana-loki ]
    ++ lib.optionals cfg.alloy.enable [ grafana-alloy ]
    ++ lib.optionals cfg.falco.enable [ pkgs.falco ]
    ++ lib.optionals cfg.otel.enable [
      (
        pkgs.opentelemetry-collector-contrib
          or pkgs.otelcol-contrib
          or pkgs.opentelemetry-collector
      )
    ];
}
