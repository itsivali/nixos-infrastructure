##############################################################################
#
# Firefox Enterprise Policies
#
# Purpose
# -------
# System-wide Firefox Enterprise Policies via /etc/firefox/policies/policies.json.
# This is the standard Linux path Firefox reads at startup, independent of how
# Firefox was installed (Home Manager, system packages, or Nix wrapper).
#
# The previous approach wrote policies.json into the Firefox profile directory
# (~/.mozilla/firefox/ivali/policies/policies.json) which is NOT read by Firefox
# for Enterprise Policies. Firefox only reads Enterprise Policies from:
#   - /etc/firefox/policies/policies.json (Linux system-wide, recommended)
#   - <install-dir>/distribution/policies.json (vendor-specific)
#
# Ownership
# ---------
# environment.etc."firefox/policies/policies.json"
#
# Dependencies
# ------------
# - None (standalone)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop;

  # Sites that require camera + microphone access for video conferencing
  cameraMicSites = [
    "https://meet.google.com"
    "https://teams.microsoft.com"
    "https://slack.com"
    "https://discord.com"
    "https://zoom.us"
  ];

  # Sites that require screen sharing (via Permissions.ScreenShare, NOT
  # the obsolete DesktopCapture key).
  screenShareSites = [
    "https://meet.google.com"
    "https://teams.microsoft.com"
    "https://slack.com"
    "https://discord.com"
    "https://zoom.us"
  ];

  # Complete policies JSON
  policiesJson = {
    policies = {
      # Camera: allow conferencing sites to prompt for camera access.
      # BlockNewRequests = false allows prompts (first-use consent model).
      Permissions = {
        Camera = {
          Allow = cameraMicSites;
          BlockNewRequests = false;
        };

        Microphone = {
          Allow = cameraMicSites;
          BlockNewRequests = false;
        };

        # ScreenShare is the current Firefox Enterprise Policy key
        # (replaces the obsolete DesktopCapture key).
        ScreenShare = {
          Allow = screenShareSites;
          BlockNewRequests = false;
        };
      };
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    # Write policies to the standard Linux system-wide location.
    # Firefox reads this path at startup regardless of how it was installed.
    environment.etc."firefox/policies/policies.json" = {
      text = builtins.toJSON policiesJson;
    };
  };
}
