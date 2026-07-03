##############################################################################
#
# SLO/SLI Definitions
#
# Purpose
# -------
# Define Service Level Objectives (SLOs) and Service Level Indicators (SLIs)
# for critical system services.
#
# Ownership
# ---------
# services.prometheus
#
# Responsibilities
# ----------------
# - Availability SLOs for critical services
# - Latency SLIs for user-facing services
# - Error budget tracking
# - SLO burn rate alerting
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
in
{
  options.ivali.observability.slo = {
    enable = lib.mkEnableOption "SLO/SLI definitions and tracking";

    availabilityTarget = lib.mkOption {
      type = lib.types.float;
      default = 99.9;
      description = "Target availability percentage for critical services";
    };

    latencyTargetMs = lib.mkOption {
      type = lib.types.int;
      default = 500;
      description = "Target latency in milliseconds for user-facing services";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.slo.enable) {
    services.prometheus = {
      ruleFiles = [
        (builtins.toFile "slo-rules.yml" ''
          groups:
            - name: slo
              rules:
                # Availability SLI: successful requests / total requests
                - record: slo:availability:ratio_rate5m
                  expr: |
                    1 - (
                      sum(rate(node_systemd_unit_state{state="failed"}[5m])) by (host)
                      /
                      sum(rate(node_systemd_unit_state[5m])) by (host)
                    )

                - record: slo:availability:ratio_rate30m
                  expr: |
                    1 - (
                      sum(rate(node_systemd_unit_state{state="failed"}[30m])) by (host)
                      /
                      sum(rate(node_systemd_unit_state[30m])) by (host)
                    )

                # Availability SLO burn rate (1h window)
                - record: slo:availability:burn_rate1h
                  expr: |
                    (1 - slo:availability:ratio_rate5m) / (1 - ${toString cfg.slo.availabilityTarget / 100})

                # Availability SLO burn rate (6h window)
                - record: slo:availability:burn_rate6h
                  expr: |
                    (1 - slo:availability:ratio_rate30m) / (1 - ${toString cfg.slo.availabilityTarget / 100})

                # Latency SLI: percentage of requests under target latency
                - record: slo:latency:ratio_rate5m
                  expr: |
                    histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) < ${toString (cfg.slo.latencyTargetMs / 1000)}

                # Error budget remaining (30-day window)
                - record: slo:error_budget:remaining
                  expr: |
                    (
                      (30 * 24 * 60 * 60) * ${toString cfg.slo.availabilityTarget / 100}
                      -
                      sum(increase(node_systemd_unit_state{state="failed"}[30d])) by (host)
                    ) / (30 * 24 * 60 * 60) * 100

          - name: slo_alerts
            rules:
              # High error burn rate (1h) - critical
              - alert: SLOErrorBudgetBurnHigh
                expr: slo:availability:burn_rate1h > 14.4
                for: 2m
                labels:
                  severity: critical
                  slo: availability
                annotations:
                  summary: "High error budget burn rate on {{ $labels.host }}"
                  description: "Error budget burning at {{ $value }}x normal rate. Will exhaust budget in <2 days."

              # Moderate error burn rate (6h) - warning
              - alert: SLOErrorBudgetBurnModerate
                expr: slo:availability:burn_rate6h > 6
                for: 15m
                labels:
                  severity: warning
                  slo: availability
                annotations:
                  summary: "Moderate error budget burn rate on {{ $labels.host }}"
                  description: "Error budget burning at {{ $value }}x normal rate. Will exhaust budget in <7 days."

              # Error budget low
              - alert: SLOErrorBudgetLow
                expr: slo:error_budget:remaining < 25
                for: 5m
                labels:
                  severity: warning
                  slo: availability
                annotations:
                  summary: "Low error budget on {{ $labels.host }}"
                  description: "Only {{ $value }}% of error budget remaining for the month."

              # Error budget exhausted
              - alert: SLOErrorBudgetExhausted
                expr: slo:error_budget:remaining <= 0
                for: 0m
                labels:
                  severity: critical
                  slo: availability
                annotations:
                  summary: "Error budget exhausted on {{ $labels.host }}"
                  description: "Error budget has been exhausted. Service is below SLO target."

              # Latency SLO violation
              - alert: SLOLatencyViolation
                expr: slo:latency:ratio_rate5m == 0
                for: 5m
                labels:
                  severity: warning
                  slo: latency
                annotations:
                  summary: "Latency SLO violation on {{ $labels.host }}"
                  description: "P99 latency exceeds ${toString cfg.slo.latencyTargetMs}ms target."
        '')
      ];
    };
  };
}
