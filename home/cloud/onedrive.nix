##############################################################################
#
# Home — Cloud: OneDrive Integration
#
# Purpose
# -------
# Declarative OneDrive file synchronization using the open-source
# onedrive client (v2.5, abraunegg fork) per the IVALi Desktop spec.
#
# The service runs as a systemd user unit, synchronizing bidirectionally
# between `~/OneDrive` and Microsoft OneDrive.
#
# Ownership
# ---------
# systemd.user.services.onedrive, home.file (config)
#
# Behavior
# --------
# First-time authentication: run `onedrive --monitor` manually in a
# terminal. A browser opens for Microsoft SSO. After auth, the token
# is stored in the system keyring. The systemd service then handles
# all subsequent sync automatically.
#
# Manual sync trigger:
#   onedrive --synchronize --single-directory ~/OneDrive
#
# Status:
#   onedrive --display-sync-status
#
##############################################################################

{ config, pkgs, lib, ... }:

let
  syncDir = "OneDrive";
in
{
  home.packages = [ pkgs.onedrive ];

  # OneDrive CLI configuration
  home.file.".config/onedrive/config" = {
    text = ''
      # OneDrive synchronization configuration
      # Sync root: ~/OneDrive (default). Values must be quoted — the
      # onedrive parser rejects unquoted values (malformed config line).
      # `monitor` is NOT a config key: it is a CLI flag only, already
      # passed by the systemd unit's ExecStart (--monitor).
      sync_dir = "${config.home.homeDirectory}/${syncDir}"
      # Skip root directory checks (faster startup)
      skip_dotfiles = "false"
      skip_dir = ""
      # Download only changed files (bandwidth optimization)
      download_only = "false"
      # Disable notification popups (silent background sync)
      disable_notifications = "true"
    '';
  };

  systemd.user.services.onedrive = {
    Unit = {
      Description = "OneDrive file synchronization";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      # onedrive does not implement sd_notify; Type=notify would leave the
      # unit forever in "activating". simple marks it active on spawn.
      Type = "simple";
      ExecStart = "${pkgs.onedrive}/bin/onedrive --monitor";
      Restart = "on-failure";
      RestartSec = 30;
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
