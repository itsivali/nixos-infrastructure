##############################################################################
#
# DevOps / Platform Engineering
#
# Purpose
# -------
# Full platform engineering toolkit for infrastructure as code,
# container orchestration, configuration management, secrets management,
# service discovery, and GitOps.
#
# Packages are opt-in to reduce evaluation and build time. Enable only
# the categories you need via the ivali.devops options.
#
# Ownership
# ---------
# options.ivali.devops
#
# Does NOT Own
# ------------
# - Google Cloud SDK (cloud/default.nix)
# - Docker daemon (virtualization/docker.nix)
# - Shell aliases (developer/aliases.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.devops;
in
{
  options.ivali.devops = {
    enable = lib.mkEnableOption "DevOps tooling (IaC, K8s, container tools)";

    terraform = {
      enable = lib.mkEnableOption "Terraform/OpenTofu IaC tools";
    };

    kubernetes = {
      enable = lib.mkEnableOption "Kubernetes tooling (kubectl, helm, kustomize)";
    };

    containers = {
      enable = lib.mkEnableOption "Container tools (docker-compose)";
    };

    ci = {
      enable = lib.mkEnableOption "CI/linting tools (shellcheck, golangci-lint)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # ── CI / Linting (needed by GitLab runner Shell executor) ──────────
    ] ++ lib.optionals cfg.ci.enable [
      shellcheck
      golangci-lint

      # ── Infrastructure as Code ──────────────────────────────────────────
    ] ++ lib.optionals cfg.terraform.enable [
      terraform
      opentofu
      terraform-ls

      # ── Kubernetes ──────────────────────────────────────────────────────
    ] ++ lib.optionals cfg.kubernetes.enable [
      kubectl
      kubernetes-helm
      kustomize
      kubectx

      # ── Container Tools ─────────────────────────────────────────────────
    ] ++ lib.optionals cfg.containers.enable [
      docker-compose
    ];
  };
}
