##############################################################################
#
# Cloud Options
#
# Purpose
# -------
# Option declarations for the Google Cloud SDK and GKE module.
#
# Ownership
# ---------
# options.ivali.cloud
#
##############################################################################

{ lib, ... }:

{
  options.ivali.cloud = {
    enable = lib.mkEnableOption "Google Cloud SDK and GKE tooling";

    projectId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "my-gcp-project";
      description = "Default GCP project ID for gcloud commands.";
    };

    region = lib.mkOption {
      type = lib.types.str;
      default = "us-central1";
      description = "Default GCP region for compute and GKE operations.";
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "us-central1-a";
      description = "Default GCP zone for compute operations.";
    };
  };
}
