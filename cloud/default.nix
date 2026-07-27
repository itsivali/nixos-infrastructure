##############################################################################
#
# Cloud — Google Cloud Platform
#
# Purpose
# -------
# Google Cloud SDK, GKE tooling, and GCP project configuration for
# cloud-native development and SRE workflows.
#
# Ownership
# ---------
# options.ivali.cloud
#
# Responsibilities
# ----------------
# - Google Cloud SDK (gcloud CLI) for GCP API access, IAM, compute
# - Kubernetes tooling for GKE (kubectl, helm, kubectx, kubens)
# - Default project/region/zone configuration
# - Shell aliases for common GCP operations
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.cloud;
in
{
  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Google Cloud SDK
      google-cloud-sdk

      # Kubernetes (GKE)
      kubectl
      kubernetes-helm
      kubectx
      kustomize
    ];

    # Default GCP project/region/zone
    environment.sessionVariables = lib.mkMerge [
      (lib.mkIf (cfg.projectId != null) {
        GOOGLE_PROJECT = cfg.projectId;
        GCLOUD_PROJECT = cfg.projectId;
        CLOUDSDK_CORE_PROJECT = cfg.projectId;
      })
      {
        CLOUDSDK_COMPUTE_REGION = cfg.region;
        CLOUDSDK_COMPUTE_ZONE = cfg.zone;
      }
    ];
  };
}
