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
# Ownership
# ---------
# environment.systemPackages for DevOps tooling
#
# Does NOT Own
# ------------
# - Google Cloud SDK (cloud/default.nix)
# - Docker daemon (virtualization/docker.nix)
# - Shell aliases (developer/aliases.nix)
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── CI / Linting (needed by GitLab runner Shell executor) ──────────
    shellcheck
    golangci-lint

    # ── Infrastructure as Code ──────────────────────────────────────────
    terraform
    opentofu
    terraform-ls
    packer

    # ── Kubernetes ──────────────────────────────────────────────────────
    kubectl
    kubernetes-helm
    kustomize
    kubectx

    # ── Configuration Management ────────────────────────────────────────
    ansible

    # ── Secrets Management ──────────────────────────────────────────────
    vault

    # ── Service Discovery / Mesh ────────────────────────────────────────
    consul

    # ── GitOps ──────────────────────────────────────────────────────────
    argocd

    # ── Container Tools ─────────────────────────────────────────────────
    docker-compose
  ];
}
