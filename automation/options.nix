# automation/options.nix
#
# Fleet Automation Module Options
#
# This module declares all configuration options consumed by the
# automation module. These options become available as:
#
#   config.fleet.gitops.*
#   config.fleet.notifications.*
#

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

      telegram = {

        chatId = mkOption {
          type = types.str;
          default = "";
          example = "7724444807";
          description = ''
            Telegram chat ID used for deployment notifications.
          '';
        };

      };

    };

    ############################################################
    # Telegram Bot Control Plane
    ############################################################

    bot = {

      enable = lib.mkEnableOption "Telegram bot control plane";

      gitlabUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "https://gitlab.com/willisivali/nixos-infrastructure";
        description = ''
          GitLab instance URL for bot API access (pipelines, MRs, etc.).
        '';
      };

      defaultUser = lib.mkOption {
        type = lib.types.str;
        default = "ivali";
        description = ''
          System user to run GUI commands as (for DISPLAY/WAYLAND access).
        '';
      };

    };

  };
}
