##############################################################################
#
# Automation Options
#
# Purpose
# -------
# Declares all configuration options consumed by the automation modules,
# including GitOps, reconciler, and notification settings.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Declare fleet.gitops options (repo URL, branch)
# - Declare fleet.gitopsReconciler options (retries, doctor, canary)
# - Declare fleet.notifications options (email, OAuth2)
#
##############################################################################

{ lib
, ...
}:

with lib;

{
  options.fleet = {

    ############################################################
    # GitOps Configuration
    ############################################################

    gitops = {

      repo = mkOption {
        type = types.str;
        default = "";
        example = "https://gitlab.com/willisivali/nixos-infrastructure";
        description = ''
          Git repository used for GitOps reconciliation.
        '';
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        example = "main";
        description = ''
          Git branch monitored by the GitOps reconciler.
        '';
      };

    };

    ############################################################
    # GitOps Reconciler Configuration
    ############################################################

    gitopsReconciler = {

      maxRetries = mkOption {
        type = types.int;
        default = 3;
        description = "Max retries for transient operations (git fetch, git pull)";
      };

      retryDelay = mkOption {
        type = types.str;
        default = "5";
        description = "Initial retry backoff delay in seconds";
      };

      useIvaliDoctor = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Use ivali doctor for post-deployment health checks.
          Falls back to deployment-health.sh when unavailable.
        '';
      };

      canary = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Run a NixOS VM smoke test (canary) before activating a new
          generation. Adds a full VM build + boot to every deploy; set to
          false to deploy directly after flake check + build.
        '';
      };

    };

    ############################################################
    # Notification Configuration
    ############################################################

    notifications = {

      email = mkOption {
        type = types.str;
        default = "";
        example = "admin@example.com";
        description = ''
          Email address used for infrastructure notifications.
        '';
      };

      oauthClientId = mkOption {
        type = types.str;
        default = "";
        example = "00000000-0000-0000-0000-000000000000";
        description = ''
          Entra ID (Azure AD) public-client application (client) ID used for
          Outlook/Office365 SMTP OAuth2 via oauth2ms. Register a public
          "Mobile & desktop" app and grant the delegated `SMTP.Send`
          permission for `https://outlook.office365.com`.
        '';
      };

      oauthTenant = mkOption {
        type = types.str;
        default = "consumers";
        example = "consumers";
        description = ''
          Entra ID tenant for the OAuth2 device-code flow. Use `consumers`
          for a personal @outlook.com account, or your organization tenant
          ID / `organizations` for Microsoft 365.
        '';
      };

    };

  };
}
